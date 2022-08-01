use nvim_oxi::{self as oxi, api, opts::*, types::*};

use crate::Client;

mod obsidian_open;

pub(crate) fn setup(client: &Client) -> oxi::Result<()> {
    let open = client.create_fn(|client, args: CommandArgs| {
        obsidian_open::obsidian_open(client, args.bang, args.fargs)
    });

    let opts = CreateCommandOpts::builder()
        .bang(true)
        .nargs(CommandNArgs::ZeroOrOne)
        .build();

    api::create_user_command("ObsidianOpen", open, Some(&opts))?;

    Ok(())
}
