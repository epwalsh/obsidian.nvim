use nvim_oxi::{self as oxi, api, opts::SetHighlightOpts};

pub(crate) fn setup() -> oxi::Result<()> {
    let mut opts = SetHighlightOpts::builder();
    opts.default(true);

    api::set_hl(0, BAD_OPTION_PATH, Some(&opts.link("Statement").build()))?;
    api::set_hl(0, ERROR_MSG_TAG, Some(&opts.link("ErrorMsg").build()))?;
    api::set_hl(0, INFO_MSG_TAG, Some(&opts.link("Question").build()))?;
    api::set_hl(0, MSG_DQUOTED, Some(&opts.link("Special").build()))?;
    api::set_hl(0, WARNING_MSG_TAG, Some(&opts.link("WarningMsg").build()))?;

    Ok(())
}

pub(crate) use consts::*;

mod consts {
    pub use messages::*;

    mod messages {
        /// Highlights the path of the config option that caused a
        /// deserialization error.
        pub const BAD_OPTION_PATH: &str = "ObsidianBadOptionPath";

        /// Highlights the prefix tag of error messages.
        pub const ERROR_MSG_TAG: &str = "ObsidianErrorMsgTag";

        /// Highlights the prefix tag of info messages.
        pub const INFO_MSG_TAG: &str = "ObsidianInfoMsgTag";

        /// Highlights double quoted strings in the error message.
        pub const MSG_DQUOTED: &str = "ObsidianMsgField";

        /// Highlights the prefix tag of warning messages.
        pub const WARNING_MSG_TAG: &str = "ObsidianWarningMsgTag";
    }
}
