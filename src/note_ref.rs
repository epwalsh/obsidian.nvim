use std::fmt;

use crate::{Error, Result};

#[derive(PartialEq, Eq, Debug)]
pub struct NoteRef {
    pub id: String,
    pub alias: Option<String>,
}

impl NoteRef {
    pub fn new(id: &str, alias: Option<&str>) -> Self {
        NoteRef {
            id: id.to_string(),
            alias: alias.map(|s| s.to_string()),
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
                alias: Some(suffix.to_string()),
            })
        } else {
            Ok(Self {
                id: bare_value.to_string(),
                alias: None,
            })
        }
    }
}

impl fmt::Display for NoteRef {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if let Some(alias) = &self.alias {
            write!(f, "[[{}|{}]]", self.id, alias)
        } else {
            write!(f, "[[{}]]", self.id)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_note_ref() {
        let note_ref = NoteRef::try_from("[[12345-ZXYD|foo]]").unwrap();
        assert_eq!(note_ref.id, "12345-ZXYD");
        assert_eq!(note_ref.alias, Some("foo".to_string()));
    }

    #[test]
    fn test_note_ref_no_alias() {
        let note_ref = NoteRef::try_from("[[12345-ZXYD]]").unwrap();
        assert_eq!(note_ref.id, "12345-ZXYD");
        assert_eq!(note_ref.alias, None);
    }
}
