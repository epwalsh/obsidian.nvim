use nvim_oxi::{Dictionary, Function, LuaPoppable, LuaPushable, Object};
use std::cell::RefCell;
use std::path::PathBuf;
use std::rc::Rc;

use crate::config::Config;
use crate::messages;
use crate::setup;
use crate::Error;

#[derive(Default)]
pub struct Client(Rc<RefCell<State>>);

struct State {
    // Whether setup function has been called.
    did_setup: bool,

    notes_dir: PathBuf,
}

impl State {
    fn new() -> Self {
        State {
            did_setup: false,
            notes_dir: PathBuf::from("./"),
        }
    }
}

impl Default for State {
    fn default() -> Self {
        State::new()
    }
}

impl From<&Rc<RefCell<State>>> for Client {
    fn from(state: &Rc<RefCell<State>>) -> Self {
        Self(Rc::clone(state))
    }
}

impl Client {
    #[inline]
    pub(crate) fn already_setup(&self) -> bool {
        self.0.borrow().did_setup
    }

    #[inline]
    pub(crate) fn did_setup(&self) {
        self.0.borrow_mut().did_setup = true;
    }

    pub(crate) fn setup(&self) -> Function<Object, ()> {
        self.create_fn(setup::setup)
    }

    pub(crate) fn set_config(&self, config: Config) {
        let state = &mut self.0.borrow_mut();
        state.notes_dir = config.notes_dir;
    }

    #[inline]
    /// Creates a new [`Client`].
    pub fn new() -> Self {
        Self::default()
    }

    /// Returns a [`Dictionary`] representing the public API of the plugin.
    pub fn build_api(&self) -> Dictionary {
        Dictionary::from_iter([("setup", Object::from(self.setup()))])
    }

    pub(crate) fn create_fn<F, A, R, E>(&self, fun: F) -> Function<A, R>
    where
        F: Fn(&Self, A) -> Result<R, E> + 'static,
        A: LuaPoppable,
        R: LuaPushable + Default,
        E: Into<Error>,
    {
        let state = Rc::clone(&self.0);
        Function::from_fn(
            move |args| match fun(&Client::from(&state), args).map_err(Into::into) {
                Ok(ret) => Ok(ret),

                Err(err) => match err {
                    Error::NvimError(nvim) => Err(nvim),

                    other => {
                        messages::echoerr!("{other}");
                        Ok(R::default())
                    }
                },
            },
        )
    }
}
