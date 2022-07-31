use serde::Deserialize;
use std::path::PathBuf;

fn default_notes_dir() -> PathBuf {
    PathBuf::from("./")
}

#[derive(Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct Config {
    #[serde(default = "default_notes_dir")]
    pub(crate) notes_dir: PathBuf,
}
