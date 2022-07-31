use nvim_oxi::{self as oxi, api, opts::*, print, types::*};

use crate::Client;

pub(crate) fn setup(_client: &Client) -> oxi::Result<()> {
    // Create a new `Greetings` command.
    let opts = CreateCommandOpts::builder()
        .bang(true)
        .desc("shows a greetings message")
        .nargs(CommandNArgs::ZeroOrOne)
        .build();
    let greetings = |args: CommandArgs| {
        let who = args.args.unwrap_or_else(|| "from Rust".to_owned());
        let bang = if args.bang { "!" } else { "" };
        print!("Hello {}{}", who, bang);
        Ok(())
    };
    api::create_user_command("Greetings", greetings, Some(&opts))?;
    Ok(())
}
