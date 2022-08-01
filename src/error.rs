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

    #[error("invalid arguments to command `{command}`: {why}")]
    InvalidArguments { command: String, why: String },

    #[error("internal error: {why}")]
    InternalError { why: String },

    #[error("cursor is not on a reference")]
    NoReference,

    #[error("file '{file}' not found")]
    FileNotFound { file: String },

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
