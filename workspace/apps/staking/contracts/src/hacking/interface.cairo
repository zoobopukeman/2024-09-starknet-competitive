#[starknet::interface]
pub trait IHacking<TContractState> {
    fn stacking_claim_rewards_attack(ref self: TContractState);
    fn stacking_claim_rewards_callback(ref self: TContractState);
}
