use nvim_oxi::{object, Object, ObjectKind};

use crate::commands;
use crate::hlgroups;
use crate::{config::Config, Client, Error, Result};

pub(crate) fn setup(client: &Client, preferences: Object) -> Result<()> {
    if client.already_setup() {
        return Err(Error::AlreadySetup);
    }

    // Set the highlight groups *before* deserializing the preferences so that
    // error messages will be displayed with the right colors.
    hlgroups::setup()?;

    let config = match preferences.kind() {
        ObjectKind::Nil => Config::default(),

        _ => {
            let deserializer = object::Deserializer::new(preferences);
            serde_path_to_error::deserialize::<_, Config>(deserializer)?
        }
    };

    commands::setup(client)?;

    client.set_config(config);
    client.did_setup();

    Ok(())
}
