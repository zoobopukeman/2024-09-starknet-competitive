pub mod interface;

pub mod hacking;

//convenient reference
pub use hacking::Hacking;
pub use interface::{IHacking};

#[cfg(test)]
mod test;
