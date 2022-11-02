if [[ "$1" ]]
then
    RULE="--rule $1"
fi

if [[ "$2" ]]
then
    MSG=": $2"
fi

certora/scripts/monger.sh DripsHub.sol

#certoraRun  certora/harness/DripsHubHarness.sol \
#certoraRun  src/DripsHub.sol \
#--link  DripsHubHarness:reserve=Reserve \
#--verify DripsHubHarness:certora/specs/DripsHub.spec \
#--verify DripsHub:certora/specs/DripsHub.spec \

            # lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol \
            # lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol \

# certoraRun  certora/harness/UpdateReceiverStatesHarness.sol \
#             src/Reserve.sol \
#             lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol \
# --verify UpdateReceiverStatesHarness:certora/specs/DripsHub.spec \
# --link  UpdateReceiverStatesHarness:reserve=Reserve \
certoraRun  certora/harness/SplitsHarness.sol \
--verify SplitsHarness:certora/specs/Splits.spec \
--packages openzeppelin-contracts=lib/openzeppelin-contracts/contracts \
--path . \
--solc solc8.17 \
--loop_iter 2 \
--optimistic_loop \
--staging \
--send_only \
$RULE  \
--msg "radicle Splits-$RULE $MSG" \
--rule_sanity
