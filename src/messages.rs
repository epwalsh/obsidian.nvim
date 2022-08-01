use nvim_oxi::api;

/// The tag used as a prefix in all the messages.
const MSG_TAG: &str = "[obsidian]";

#[macro_export]
macro_rules! echoerr {
    ($($arg:tt)*) => {{
        $crate::messages::echo(
            ::std::fmt::format(format_args!($($arg)*)),
            $crate::hlgroups::ERROR_MSG_TAG
        );
    }}
}

#[macro_export]
macro_rules! echoinfo {
    ($($arg:tt)*) => {{
        $crate::messages::echo(
            ::std::fmt::format(format_args!($($arg)*)),
            $crate::hlgroups::INFO_MSG_TAG
        );
    }}
}

#[macro_export]
macro_rules! echowarn {
    ($($arg:tt)*) => {{
        $crate::messages::echo(
            ::std::fmt::format(format_args!($($arg)*)),
            $crate::hlgroups::WARNING_MSG_TAG
        );
    }}
}

pub(crate) use echoerr;
pub(crate) use echoinfo;
// pub(crate) use echowarn;

pub(crate) fn echo(msg: String, tag_hlgroup: &'static str) {
    let chunks = [(MSG_TAG, Some(tag_hlgroup)), (" ", None), (&msg, None)];
    let _ = api::echo(chunks, true);
}
