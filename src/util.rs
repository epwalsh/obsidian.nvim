use lazy_static::lazy_static;
use regex::Regex;
use unicode_segmentation::UnicodeSegmentation;

use nvim_oxi as oxi;

use crate::{NoteRef, Result};

pub(crate) fn get_ref_under_cursor() -> Result<Option<NoteRef>> {
    let (_, pos) = oxi::api::get_current_win().get_position()?;
    let line = oxi::api::get_current_line()?;
    find_ref(&line, pos)
}

fn find_ref(line: &str, pos: usize) -> Result<Option<NoteRef>> {
    lazy_static! {
        static ref RE: Regex = Regex::new(r"\[\[([^\]]+)\]\]").unwrap();
    }

    // The `pos` argument is the display position within the line, which is
    // equivalent to an index into the unicode grapheme clusters.
    // But we really need the position with respect to bytes.
    let graphemes = line.graphemes(true).collect::<Vec<&str>>();
    let pos_in_bytes: usize = graphemes[0..pos].iter().map(|s| s.len()).sum();

    for m in RE.find_iter(line) {
        if m.start() <= pos_in_bytes && pos_in_bytes <= m.end() {
            return Ok(Some(NoteRef::try_from(m.as_str())?));
        }
    }

    Ok(None)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_find_ref() {
        assert_eq!(
            find_ref("[[12345-ZXYD|foo]] blah", 0).unwrap().unwrap(),
            NoteRef::try_from("[[12345-ZXYD|foo]]").unwrap()
        );

        assert_eq!(
            find_ref("[[12345-ZXYD|foo]] blah", 17).unwrap().unwrap(),
            NoteRef::try_from("[[12345-ZXYD|foo]]").unwrap(),
        );

        assert_eq!(find_ref("[[12345-ZXYD|foo]]  blah", 19).unwrap(), None);
    }
}
