use eyre::WrapErr;
use serde::Deserialize;
use std::{fs::File, io::Read, path::PathBuf};
use structopt::StructOpt;

#[derive(StructOpt, Debug)]
#[structopt(name = "demo", about = "A binary with a configuration file.")]
struct CliArgs {
    /// A path to a configuration file
    #[structopt(
        short,
        long,
        parse(from_os_str),
        env = "DEMO_CONFIG",
        default_value = "/etc/demo.toml"
    )]
    pub config: PathBuf,
}

#[derive(Deserialize, Debug)]
struct Config {
    /// A togglable switch
    #[allow(dead_code)]
    #[serde(default)]
    switch: bool,
}

fn main() -> color_eyre::eyre::Result<()> {
    color_eyre::install()?;

    let cli_args = CliArgs::from_args();
    println!("{:#?}", cli_args);

    let mut config_file = File::open(&cli_args.config)
        .wrap_err_with(|| format!("Failed to open config {}", cli_args.config.display()))?;

    let mut config_string = String::default();
    config_file
        .read_to_string(&mut config_string)
        .wrap_err_with(|| format!("Failed to read config {}", cli_args.config.display()))?;

    let config: Config = toml::from_str(&config_string)
        .wrap_err_with(|| format!("Failed to parse config {}", cli_args.config.display()))?;
    println!("{:#?}", config);

    Ok(())
}
