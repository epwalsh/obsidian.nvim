use crate::Result;

pub struct Note {
    pub id: String,
    pub aliases: Vec<String>,
    pub tags: Vec<String>,
}

impl Note {
    pub fn new(id: &str) -> Self {
        Note {
            id: id.to_string(),
            aliases: vec![],
            tags: vec![],
        }
    }

    /// Add an alias to the note.
    pub fn with_alias(mut self, alias: &str) -> Self {
        self.aliases.push(alias.to_string());
        self
    }

    /// Add a tag to the note.
    pub fn with_tag(mut self, tag: &str) -> Self {
        self.tags.push(tag.to_string());
        self
    }

    /// Returns the YAML-formatted frontmatter lines for the note.
    pub fn frontmatter(&self) -> Result<Vec<String>> {
        use serde_yaml::{Mapping, Value};

        let cast_vec = |v: &Vec<String>| -> Value {
            Value::Sequence(v.iter().map(|s| Value::String(s.clone())).collect())
        };

        let frontmatter = Mapping::from_iter(
            [
                ("id", Value::String(self.id.clone())),
                ("aliases", cast_vec(&self.aliases)),
                ("tags", cast_vec(&self.tags)),
            ]
            .into_iter()
            .map(|x| (Value::String(x.0.to_string()), x.1)),
        );
        let frontmatter_str = serde_yaml::to_string(&frontmatter)?;

        let mut lines: Vec<String> = vec!["---".to_string()];
        for line in frontmatter_str.lines() {
            lines.push(line.to_string());
        }
        lines.push("---".to_string());
        Ok(lines)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_frontmatter() {
        let note = Note::new("foo").with_alias("bar");
        assert_eq!(
            note.frontmatter().unwrap(),
            vec!["---", "id: foo", "aliases:", "- bar", "tags: []", "---"]
        );
    }

    #[test]
    fn test_frontmatter_with_tags() {
        let note = Note::new("foo").with_alias("bar").with_tag("baz");
        assert_eq!(
            note.frontmatter().unwrap(),
            vec!["---", "id: foo", "aliases:", "- bar", "tags:", "- baz", "---"]
        );
    }
}
