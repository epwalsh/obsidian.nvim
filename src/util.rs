use std::fmt;

use lazy_static::lazy_static;
use regex::Regex;
use unicode_segmentation::UnicodeSegmentation;

use nvim_oxi as oxi;

use crate::{Error, Result};

#[derive(PartialEq, Eq, Debug)]
pub struct NoteRef {
    pub id: String,
    pub tag: Option<String>,
}

impl NoteRef {
    pub fn new(id: &str, tag: Option<&str>) -> Self {
        NoteRef {
            id: id.to_string(),
            tag: tag.map(|s| s.to_string()),
        }
    }

    pub fn filename(&self) -> String {
        format!("{}.md", self.id)
    }
}

impl TryFrom<&str> for NoteRef {
    type Error = Error;

    fn try_from(value: &str) -> Result<Self> {
        if !value.starts_with("[[") || !value.ends_with("]]") {
            return Err(Error::InternalError {
                why: "Bad NoteRef value".to_string(),
            });
        }

        let bare_value: &str = value
            .strip_prefix("[[")
            .ok_or_else(|| Error::InternalError {
                why: "Bad NoteRef string".to_string(),
            })?
            .strip_suffix("]]")
            .ok_or_else(|| Error::InternalError {
                why: "Bad NoteRef string".to_string(),
            })?;

        if let Some((prefix, suffix)) = bare_value.split_once('|') {
            Ok(Self {
                id: prefix.to_string(),
                tag: Some(suffix.to_string()),
            })
        } else {
            Ok(Self {
                id: bare_value.to_string(),
                tag: None,
            })
        }
    }
}

impl fmt::Display for NoteRef {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if let Some(tag) = &self.tag {
            write!(f, "[[{}|{}]]", self.id, tag)
        } else {
            write!(f, "[[{}]]", self.id)
        }
    }
}

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
    fn test_note_ref() {
        let note_ref = NoteRef::try_from("[[12345-ZXYD|foo]]").unwrap();
        assert_eq!(note_ref.id, "12345-ZXYD");
        assert_eq!(note_ref.tag, Some("foo".to_string()));
    }

    #[test]
    fn test_note_ref_no_tag() {
        let note_ref = NoteRef::try_from("[[12345-ZXYD]]").unwrap();
        assert_eq!(note_ref.id, "12345-ZXYD");
        assert_eq!(note_ref.tag, None);
    }

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
