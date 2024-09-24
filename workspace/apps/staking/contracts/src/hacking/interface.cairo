#[starknet::interface]
pub trait IHacking<TContractState> {
    fn claim_rewards_callback(ref self: TContractState);
}
