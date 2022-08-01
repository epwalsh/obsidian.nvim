use nvim_oxi as oxi;

use crate::{messages, util, Client, Error, NoteRef, Result};

#[allow(unused_variables)]
pub(super) fn obsidian_open(client: &Client, bang: bool, refs: Vec<String>) -> Result<()> {
    let note_ref = if refs.is_empty() || refs[0].is_empty() {
        util::get_ref_under_cursor()?.ok_or(Error::NoReference)?
    } else {
        let ref_id = &refs[0];
        messages::echoinfo!("{:?}", refs);
        NoteRef::new(ref_id, None)
    };

    let path = client.path_for(&note_ref);

    if !path.is_file() {
        return Err(Error::FileNotFound {
            file: path.to_string_lossy().into_owned(),
        });
    }

    messages::echoinfo!("opening {:?}", path);
    oxi::api::command(&format!("e {}", path.to_string_lossy()))?;

    Ok(())
}
