use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

#[cfg(target_os = "macos")]
const INCLUDE_P2P: u32 = 0x0002_0000;
#[cfg(target_os = "macos")]
const INCLUDE_AWDL: u32 = 0x0010_0000;
#[cfg(target_os = "macos")]
const REGISTRATION_FLAGS: u32 = INCLUDE_P2P | INCLUDE_AWDL;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BonjourInfo {
    pub enabled: bool,
    pub registered: bool,
    pub state: String,
    pub service_name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

pub struct BonjourRegistration {
    info: Arc<Mutex<BonjourInfo>>,
    #[cfg(target_os = "macos")]
    stop: Arc<std::sync::atomic::AtomicBool>,
    #[cfg(target_os = "macos")]
    thread: Option<std::thread::JoinHandle<()>>,
}

impl BonjourRegistration {
    pub fn disabled(service_name: String) -> Self {
        Self {
            info: Arc::new(Mutex::new(BonjourInfo {
                enabled: false,
                registered: false,
                state: "disabled".to_owned(),
                service_name,
                error: None,
            })),
            #[cfg(target_os = "macos")]
            stop: Arc::new(std::sync::atomic::AtomicBool::new(false)),
            #[cfg(target_os = "macos")]
            thread: None,
        }
    }

    pub fn register(service_name: String, server_id: String, port: u16) -> Result<Self, String> {
        platform::register(service_name, server_id, port)
    }

    pub fn info(&self) -> BonjourInfo {
        self.info
            .lock()
            .expect("bonjour info mutex poisoned")
            .clone()
    }
}

#[cfg(target_os = "macos")]
impl Drop for BonjourRegistration {
    fn drop(&mut self) {
        use std::sync::atomic::Ordering;
        self.stop.store(true, Ordering::Release);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

#[cfg(any(target_os = "macos", test))]
pub(crate) fn txt_record(server_id: &str, service_name: &str) -> Result<Vec<u8>, String> {
    let mut record = Vec::new();
    for field in [format!("id={server_id}"), format!("name={service_name}")] {
        let bytes = field.as_bytes();
        let length = u8::try_from(bytes.len())
            .map_err(|_| "DNS-SD TXT field exceeds 255 bytes".to_owned())?;
        record.push(length);
        record.extend_from_slice(bytes);
    }
    Ok(record)
}

#[cfg(any(target_os = "macos", test))]
pub(crate) const fn network_port_bytes(port: u16) -> [u8; 2] {
    port.to_be_bytes()
}

#[cfg(any(target_os = "macos", test))]
pub(crate) const fn network_port_value(port: u16) -> u16 {
    u16::from_ne_bytes(network_port_bytes(port))
}

#[cfg(target_os = "macos")]
mod platform {
    use super::*;
    use libc::{c_char, c_void};
    use std::ffi::{CStr, CString};
    use std::ptr;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::thread;

    type DNSServiceRef = *mut c_void;
    type DNSServiceFlags = u32;
    type DNSServiceErrorType = i32;
    type DNSServiceRegisterReply = unsafe extern "C" fn(
        sd_ref: DNSServiceRef,
        flags: DNSServiceFlags,
        error_code: DNSServiceErrorType,
        name: *const c_char,
        regtype: *const c_char,
        domain: *const c_char,
        context: *mut c_void,
    );

    extern "C" {
        fn DNSServiceRegister(
            sd_ref: *mut DNSServiceRef,
            flags: DNSServiceFlags,
            interface_index: u32,
            name: *const c_char,
            regtype: *const c_char,
            domain: *const c_char,
            host: *const c_char,
            port: u16,
            txt_len: u16,
            txt_record: *const c_void,
            callback: Option<DNSServiceRegisterReply>,
            context: *mut c_void,
        ) -> DNSServiceErrorType;
        fn DNSServiceRefSockFD(sd_ref: DNSServiceRef) -> libc::c_int;
        fn DNSServiceProcessResult(sd_ref: DNSServiceRef) -> DNSServiceErrorType;
        fn DNSServiceRefDeallocate(sd_ref: DNSServiceRef);
    }

    struct CallbackContext {
        info: Arc<Mutex<BonjourInfo>>,
    }

    pub(super) fn register(
        service_name: String,
        server_id: String,
        port: u16,
    ) -> Result<BonjourRegistration, String> {
        let service_name = sanitize_service_name(&service_name);
        let txt = txt_record(&server_id, &service_name)?;
        let txt_len = u16::try_from(txt.len())
            .map_err(|_| "DNS-SD TXT record exceeds 65535 bytes".to_owned())?;
        let info = Arc::new(Mutex::new(BonjourInfo {
            enabled: true,
            registered: false,
            state: "registering".to_owned(),
            service_name: service_name.clone(),
            error: None,
        }));
        let stop = Arc::new(AtomicBool::new(false));
        let thread_info = Arc::clone(&info);
        let thread_stop = Arc::clone(&stop);
        let thread = thread::Builder::new()
            .name("thumble-bonjour".to_owned())
            .spawn(move || {
                registration_thread(service_name, txt, txt_len, port, thread_info, thread_stop);
            })
            .map_err(|error| format!("start DNS-SD thread: {error}"))?;

        Ok(BonjourRegistration {
            info,
            stop,
            thread: Some(thread),
        })
    }

    fn registration_thread(
        service_name: String,
        txt: Vec<u8>,
        txt_len: u16,
        port: u16,
        info: Arc<Mutex<BonjourInfo>>,
        stop: Arc<AtomicBool>,
    ) {
        let name = CString::new(service_name).expect("service name was sanitized");
        // Compatibility contract: released Thumble clients discover this
        // pre-rename DNS-SD service type.
        let regtype = CString::new("_pocketpad._tcp").expect("static DNS-SD type has no NUL");
        let context = Box::new(CallbackContext {
            info: Arc::clone(&info),
        });
        let context_ptr = Box::into_raw(context);
        let mut service_ref: DNSServiceRef = ptr::null_mut();
        // SAFETY: All C strings and TXT bytes remain alive through registration;
        // the callback context remains allocated until after deallocation.
        let register_result = unsafe {
            DNSServiceRegister(
                &mut service_ref,
                REGISTRATION_FLAGS,
                0,
                name.as_ptr(),
                regtype.as_ptr(),
                ptr::null(),
                ptr::null(),
                network_port_value(port),
                txt_len,
                txt.as_ptr().cast(),
                Some(register_callback),
                context_ptr.cast(),
            )
        };
        if register_result != 0 || service_ref.is_null() {
            set_error(
                &info,
                format!("DNS-SD registration failed ({register_result})"),
            );
            // SAFETY: DNSServiceRegister will not retain the context after a
            // synchronous registration failure.
            unsafe { drop(Box::from_raw(context_ptr)) };
            return;
        }

        // ProcessResult and Deallocate intentionally happen only on this thread.
        // SAFETY: service_ref is valid until deallocated below.
        let socket = unsafe { DNSServiceRefSockFD(service_ref) };
        if socket < 0 {
            set_error(&info, "DNS-SD returned no pollable socket".to_owned());
        } else {
            while !stop.load(Ordering::Acquire) {
                let mut descriptor = libc::pollfd {
                    fd: socket,
                    events: libc::POLLIN,
                    revents: 0,
                };
                // SAFETY: descriptor points to one initialized pollfd.
                let poll_result = unsafe { libc::poll(&mut descriptor, 1, 250) };
                if poll_result > 0 {
                    if descriptor.revents & libc::POLLIN != 0 {
                        // SAFETY: service_ref remains valid and this is its sole
                        // processing/deallocation thread.
                        let result = unsafe { DNSServiceProcessResult(service_ref) };
                        if result != 0 {
                            set_error(&info, format!("DNS-SD processing failed ({result})"));
                            break;
                        }
                    } else if descriptor.revents & (libc::POLLERR | libc::POLLHUP | libc::POLLNVAL)
                        != 0
                    {
                        set_error(
                            &info,
                            format!(
                                "DNS-SD poll returned terminal events ({})",
                                descriptor.revents
                            ),
                        );
                        break;
                    }
                } else if poll_result < 0 {
                    let error = std::io::Error::last_os_error();
                    if error.kind() != std::io::ErrorKind::Interrupted {
                        set_error(&info, format!("DNS-SD poll failed: {error}"));
                        break;
                    }
                }
            }
        }

        // SAFETY: no callback processing is concurrent on this thread and the
        // service reference/context are each released exactly once.
        unsafe {
            DNSServiceRefDeallocate(service_ref);
            drop(Box::from_raw(context_ptr));
        }
        if let Ok(mut current) = info.lock() {
            current.registered = false;
            if current.error.is_none() {
                current.state = "stopped".to_owned();
            }
        }
    }

    unsafe extern "C" fn register_callback(
        _sd_ref: DNSServiceRef,
        _flags: DNSServiceFlags,
        error_code: DNSServiceErrorType,
        name: *const c_char,
        _regtype: *const c_char,
        _domain: *const c_char,
        context: *mut c_void,
    ) {
        if context.is_null() {
            return;
        }
        // SAFETY: context is the CallbackContext allocated in
        // registration_thread and remains live until service deallocation.
        let context = unsafe { &*(context.cast::<CallbackContext>()) };
        if error_code != 0 {
            set_error(
                &context.info,
                format!("DNS-SD callback failed ({error_code})"),
            );
            return;
        }
        if let Ok(mut info) = context.info.lock() {
            if !name.is_null() {
                // SAFETY: DNS-SD supplies a NUL-terminated name for callback duration.
                info.service_name = unsafe { CStr::from_ptr(name) }
                    .to_string_lossy()
                    .into_owned();
            }
            info.registered = true;
            info.state = "registered".to_owned();
            info.error = None;
        }
    }

    fn set_error(info: &Arc<Mutex<BonjourInfo>>, error: String) {
        if let Ok(mut info) = info.lock() {
            info.registered = false;
            info.state = "error".to_owned();
            info.error = Some(error);
        }
    }

    fn sanitize_service_name(name: &str) -> String {
        let sanitized = name
            .chars()
            .filter(|character| *character != '\0')
            .collect::<String>();
        let trimmed = sanitized.trim();
        if trimmed.is_empty() {
            return "Thumble Host".to_owned();
        }
        let mut result = String::new();
        for character in trimmed.chars() {
            if result.len() + character.len_utf8() > 63 {
                break;
            }
            result.push(character);
        }
        result
    }
}

#[cfg(not(target_os = "macos"))]
mod platform {
    use super::*;

    pub(super) fn register(
        service_name: String,
        _server_id: String,
        _port: u16,
    ) -> Result<BonjourRegistration, String> {
        Ok(BonjourRegistration {
            info: Arc::new(Mutex::new(BonjourInfo {
                enabled: true,
                registered: false,
                state: "unavailable".to_owned(),
                service_name,
                error: None,
            })),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn txt_record_uses_dns_length_prefixed_fields_in_order() {
        let record = txt_record("server-123", "Thumble on Mac").unwrap();
        let first = b"id=server-123";
        let second = b"name=Thumble on Mac";
        assert_eq!(record[0], first.len() as u8);
        assert_eq!(&record[1..1 + first.len()], first);
        let second_offset = 1 + first.len();
        assert_eq!(record[second_offset], second.len() as u8);
        assert_eq!(&record[second_offset + 1..], second);
    }

    #[test]
    fn dns_service_port_value_has_network_order_memory_bytes() {
        let value = network_port_value(0x2233);
        assert_eq!(value.to_ne_bytes(), [0x22, 0x33]);
        assert_eq!(network_port_bytes(8765), [0x22, 0x3d]);
    }

    #[test]
    fn oversized_txt_field_is_rejected_without_network_side_effects() {
        assert!(txt_record(&"x".repeat(300), "host").is_err());
    }
}
