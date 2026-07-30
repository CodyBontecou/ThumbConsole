use clap::Parser;
use thumble_host::cli::{execute, Cli};
use thumble_host::paths::HostPaths;
use thumble_host::storage;

#[tokio::main]
async fn main() {
    let paths = match HostPaths::discover() {
        Ok(paths) => paths,
        Err(error) => {
            eprintln!("thumble-host: resolve host paths: {error}");
            std::process::exit(1);
        }
    };
    let cli = Cli::parse();
    if let Err(error) = execute(cli, paths.clone()).await {
        let error = storage::redact_known_auth_tokens(&paths.state_file, &error);
        eprintln!("thumble-host: {error}");
        std::process::exit(1);
    }
}
