use core::option::OptionTrait;
use contracts::constants::{BASE_VALUE, SECONDS_IN_DAY};
use contracts::staking::{StakerInfo, StakerInfoTrait, StakerPoolInfo};
use contracts::staking::Staking::InternalStakingFunctionsTrait;
use contracts::utils::{compute_rewards_rounded_down, compute_rewards_rounded_up};
use contracts::utils::compute_commission_amount_rounded_down;
use contracts::test_utils;
use test_utils::{initialize_staking_state_from_cfg, deploy_mock_erc20_contract, StakingInitConfig};
use test_utils::{fund, approve, deploy_staking_contract, stake_with_pool_enabled};
use test_utils::{enter_delegation_pool_for_testing_using_dispatcher, load_option_from_simple_map};
use test_utils::{load_from_simple_map, load_one_felt, stake_for_testing_using_dispatcher};
use test_utils::{general_contract_system_deployment, cheat_reward_for_reward_supplier};
use test_utils::set_account_as_operator;
use test_utils::constants;
use constants::{DUMMY_ADDRESS, POOL_CONTRACT_ADDRESS, OTHER_STAKER_ADDRESS, OTHER_REWARD_ADDRESS};
use constants::{NON_STAKER_ADDRESS, POOL_MEMBER_STAKE_AMOUNT, CALLER_ADDRESS, DUMMY_IDENTIFIER};
use constants::OTHER_OPERATIONAL_ADDRESS;
use contracts::event_test_utils;
use event_test_utils::{assert_number_of_events, assert_staker_exit_intent_event};
use event_test_utils::{assert_stake_balance_changed_event, assert_delete_staker_event};
use event_test_utils::assert_staker_reward_address_change_event;
use event_test_utils::assert_new_delegation_pool_event;
use event_test_utils::assert_change_operational_address_event;
use event_test_utils::assert_new_staker_event;
use event_test_utils::assert_global_index_updated_event;
use event_test_utils::assert_rewards_supplied_to_delegation_pool_event;
use event_test_utils::assert_staker_reward_claimed_event;
use event_test_utils::{assert_paused_event, assert_unpaused_event};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use starknet::get_block_timestamp;
use contracts::staking::objects::{UndelegateIntentKey, UndelegateIntentValue};
use contracts::staking::objects::UndelegateIntentValueZero;
use contracts::staking::interface::{IStakingPoolDispatcher};
use contracts::staking::interface::{IStakingPauseDispatcher, IStakingPoolDispatcherTrait};
use contracts::staking::interface::{IStakingDispatcher, IStakingDispatcherTrait};
use contracts::staking::interface::IStakingPauseDispatcherTrait;
use contracts::staking::interface::{IStakingConfigDispatcher, IStakingConfigDispatcherTrait};
use contracts::staking::Staking::COMMISSION_DENOMINATOR;
use core::num::traits::Zero;
use contracts::staking::interface::StakingContractInfo;
use snforge_std::{cheat_caller_address, CheatSpan, cheat_account_contract_address};
use snforge_std::start_cheat_block_timestamp_global;
use snforge_std::cheatcodes::events::{EventSpyTrait, EventsFilterTrait};
use contracts_commons::test_utils::cheat_caller_address_once;
use contracts::pool::Pool::SwitchPoolData;
use contracts::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait};
use contracts_commons::components::roles::interface::{IRolesDispatcher, IRolesDispatcherTrait};

use contracts::hacking::interface::{IHackingDispatcher, IHackingDispatcherTrait};

#[test]
fn test_constructor() {
    let mut cfg: StakingInitConfig = Default::default();
    let mut state = initialize_staking_state_from_cfg(ref :cfg);
    assert_eq!(state.min_stake.read(), cfg.staking_contract_info.min_stake);
    assert_eq!(
        state.erc20_dispatcher.read().contract_address, cfg.staking_contract_info.token_address
    );
    let contract_global_index: u64 = state.global_index.read();
    assert_eq!(BASE_VALUE, contract_global_index);
    let staker_address = state
        .operational_address_to_staker_address
        .read(cfg.staker_info.operational_address);
    assert_eq!(staker_address, Zero::zero());
    let staker_info = state.staker_info.read(staker_address);
    assert!(staker_info.is_none());
    assert_eq!(
        state.pool_contract_class_hash.read(), cfg.staking_contract_info.pool_contract_class_hash
    );
    assert_eq!(
        state.reward_supplier_dispatcher.read().contract_address,
        cfg.staking_contract_info.reward_supplier
    );
    assert_eq!(state.pool_contract_admin.read(), cfg.test_info.pool_contract_admin);
}

#[test]
fn test_stacking_claim_rewards_attack() {
    let mut cfg: StakingInitConfig = Default::default();
    general_contract_system_deployment(ref :cfg);
    let token_address = cfg.staking_contract_info.token_address;
    let staking_contract = cfg.test_info.staking_contract;
    let reward_supplier = cfg.staking_contract_info.reward_supplier;

    // Stake.
    stake_for_testing_using_dispatcher(:cfg, :token_address, :staking_contract);
    // Update index in staking contract.
    snforge_std::store(
        target: staking_contract,
        storage_address: selector!("global_index"),
        serialized_value: array![(cfg.staker_info.index).into() * 2].span()
    );
    // Funds reward supplier and set his unclaimed rewards.
    let expected_reward = cfg.staker_info.amount_own;
    cheat_reward_for_reward_supplier(:cfg, :reward_supplier, :expected_reward, :token_address);

    let hacking_contract = cfg.test_info.hacking_contract;
    let hacking_disaptcher = IHackingDispatcher { contract_address: hacking_contract };
    hacking_disaptcher.stacking_claim_rewards_attack();

    // Claim rewards and validate the results.
    let mut spy = snforge_std::spy_events();
    let staking_disaptcher = IStakingDispatcher { contract_address: staking_contract };
    let staker_address = cfg.test_info.staker_address;
    cheat_caller_address_once(contract_address: staking_contract, caller_address: staker_address);
    let reward = staking_disaptcher.claim_rewards(:staker_address);
    assert_eq!(reward, expected_reward);

    let new_staker_info = staking_disaptcher.state_of(:staker_address);
    assert_eq!(new_staker_info.unclaimed_rewards_own, 0);

    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let balance = erc20_dispatcher.balance_of(cfg.staker_info.reward_address);
    assert_eq!(balance, reward.into());
    // Validate the single StakerRewardClaimed event.
    let events = spy.get_events().emitted_by(contract_address: staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "claim_rewards");
    assert_staker_reward_claimed_event(
        spied_event: events[0],
        :staker_address,
        reward_address: cfg.staker_info.reward_address,
        amount: reward
    );
}
