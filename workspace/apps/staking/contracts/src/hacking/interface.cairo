#[starknet::interface]
pub trait IHacking<TContractState> {
    fn attack(ref self: TContractState);
    fn claim_rewards_callback(ref self: TContractState);
}
