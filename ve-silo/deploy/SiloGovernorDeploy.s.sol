// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {IVotes} from "openzeppelin-contracts/governance/extensions/GovernorVotes.sol";
import {TimelockController} from "openzeppelin-contracts/governance/extensions/GovernorTimelockControl.sol";

import {SiloGovernor} from "ve-silo/contracts/governance/SiloGovernor.sol";
import {ISiloGovernor} from "ve-silo/contracts/governance/interfaces/ISiloGovernor.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";
import {ISiloTimelockController} from "ve-silo/contracts/governance/interfaces/ISiloTimelockController.sol";

import {VotingEscrowDeploy} from "./VotingEscrowDeploy.s.sol";
import {TimelockControllerDeploy} from "./TimelockControllerDeploy.s.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/SiloGovernorDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloGovernorDeploy is CommonDeploy {
    VotingEscrowDeploy public votingEscrowDeploy = new VotingEscrowDeploy();
    TimelockControllerDeploy public timelockControllerDeploy = new TimelockControllerDeploy();

    function run()
        public
        returns (
            ISiloGovernor siloGovernor,
            ISiloTimelockController timelock,
            IVeSilo votingEscrow,
            IVeBoost veBoost
        )
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        timelock = timelockControllerDeploy.run();

        vm.startBroadcast(deployerPrivateKey);

        siloGovernor = ISiloGovernor(
            address(
                new SiloGovernor(
                    TimelockController(payable(address(timelock)))
                )
            )
        );

        vm.stopBroadcast();

        _registerDeployment(address(siloGovernor), VeSiloContracts.SILO_GOVERNOR);
        _syncDeployments();

        (votingEscrow, veBoost) = votingEscrowDeploy.run();

        _configure(siloGovernor, timelock, votingEscrow);
    }

    function _configure(ISiloGovernor _governor, ISiloTimelockController _timelock, IVeSilo _votingEscrow) internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Configure a veSilo token as the token for voting in the DAO
        _governor.oneTimeInit(_votingEscrow);

        address deployer = vm.addr(deployerPrivateKey);
        address governorAddr = address(_governor);

        // Set the DAO as a proposer, an executor and a canceller
        _timelock.grantRole(_timelock.PROPOSER_ROLE(), governorAddr);
        _timelock.grantRole(_timelock.EXECUTOR_ROLE(), governorAddr);
        _timelock.grantRole(_timelock.CANCELLER_ROLE(), governorAddr);

        // Update TimelockController admin role
        _timelock.grantRole(_timelock.TIMELOCK_ADMIN_ROLE(), governorAddr);
        _timelock.revokeRole(_timelock.TIMELOCK_ADMIN_ROLE(), deployer);

        vm.stopBroadcast();
    }
}
