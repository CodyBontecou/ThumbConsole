use rmcp::schemars::schema_for;
use serde_json::Value;
use std::error::Error;
use std::fs;
use std::path::Path;
use thumble_mcp::server::ConfigurationOperationInput;

fn main() -> Result<(), Box<dyn Error>> {
    let mut value = serde_json::to_value(schema_for!(ConfigurationOperationInput))?;
    let object = value
        .as_object_mut()
        .ok_or("schema root is not an object")?;
    object.insert(
        "$id".to_owned(),
        Value::String(
            "https://codybontecou.com/thumble/schemas/configuration-operation-v1.schema.json"
                .to_owned(),
        ),
    );
    object.insert(
        "title".to_owned(),
        Value::String("Thumble Configuration Draft Operation v1".to_owned()),
    );
    object.insert(
        "description".to_owned(),
        Value::String("Strict revision-safe configuration operations. Customization fix accepts only stored/catalog/bounded-size canvases; control-bar item set and element add/set expose only bounded non-file values. Images, bytes, paths, raw key codes, modifier masks, asset IDs, raw JSON, launch targets, argv, credentials, and unknown fields are rejected.".to_owned()),
    );

    let catalog_path =
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../docs/mcp/device-frames-v1.json");
    let catalog: Value = serde_json::from_slice(&fs::read(catalog_path)?)?;
    let frame_ids = catalog
        .get("frames")
        .and_then(Value::as_array)
        .ok_or("device frame catalog has no frames")?
        .iter()
        .map(|frame| {
            frame
                .get("id")
                .and_then(Value::as_str)
                .map(|id| Value::String(id.to_owned()))
                .ok_or("device frame has no ID")
        })
        .collect::<Result<Vec<_>, _>>()?;
    object
        .get_mut("$defs")
        .and_then(Value::as_object_mut)
        .ok_or("schema has no definitions")?
        .insert(
            "deviceFrameID".to_owned(),
            serde_json::json!({"type": "string", "enum": frame_ids}),
        );
    let operations = object
        .get_mut("oneOf")
        .and_then(Value::as_array_mut)
        .ok_or("schema has no operations")?;
    let device_set = operations
        .iter_mut()
        .find(|operation| {
            operation
                .pointer("/properties/type/const")
                .and_then(Value::as_str)
                == Some("device.set")
        })
        .ok_or("schema has no device.set operation")?;
    *device_set
        .pointer_mut("/properties/frameID")
        .ok_or("device.set has no frameID")? = serde_json::json!({"$ref": "#/$defs/deviceFrameID", "description": "Exact frame ID returned by query_catalog(device-frames); custom dimensions are rejected."});
    let repair_canvas = object
        .get_mut("$defs")
        .and_then(Value::as_object_mut)
        .and_then(|definitions| definitions.get_mut("LayoutRepairCanvasInput"))
        .and_then(|definition| definition.get_mut("oneOf"))
        .and_then(Value::as_array_mut)
        .ok_or("schema has no layout repair canvas")?;
    let frame_canvas = repair_canvas
        .iter_mut()
        .find(|canvas| {
            canvas
                .pointer("/properties/source/const")
                .and_then(Value::as_str)
                == Some("frame")
        })
        .ok_or("layout repair canvas has no frame source")?;
    *frame_canvas
        .pointer_mut("/properties/frameID")
        .ok_or("layout repair frame canvas has no frameID")? = serde_json::json!({"$ref": "#/$defs/deviceFrameID", "description": "Exact checked-in frame ID returned by query_catalog(device-frames)."});

    let rendered = format!("{}\n", serde_json::to_string_pretty(&value)?);
    if let Some(path) = std::env::args_os().nth(1) {
        fs::write(path, rendered)?;
    } else {
        print!("{rendered}");
    }
    Ok(())
}
