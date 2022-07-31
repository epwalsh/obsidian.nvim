use nvim_oxi as oxi;

/// Alias for a `Result` with error type [`obsidian::Error`](Error).
pub type Result<T> = std::result::Result<T, Error>;

#[derive(thiserror::Error, Debug)]
pub enum Error {
    #[error("can't setup more than once per session")]
    AlreadySetup,

    #[error("error parsing `{option}`: {why}")]
    BadPreferences {
        option: serde_path_to_error::Path,
        why: String,
    },

    #[error(transparent)]
    NvimError(#[from] oxi::Error),
}

impl From<serde_path_to_error::Error<oxi::Error>> for Error {
    fn from(err: serde_path_to_error::Error<oxi::Error>) -> Self {
        let option = err.path().to_owned();

        match err.into_inner() {
            oxi::Error::DeserializeError(why) => Self::BadPreferences { option, why },

            other => other.into(),
        }
    }
}
