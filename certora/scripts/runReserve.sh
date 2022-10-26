if [[ "$1" ]]
then
    RULE="--rule $1"
fi

if [[ "$2" ]]
then
    MSG=": $2"
fi

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
#            lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol \
certoraRun  certora/harness/ReserveHarness.sol \
            certora/harness/DummyERC20Impl.sol \
            certora/harness/DummyERC20A.sol \
            certora/harness/DummyERC20B.sol \
--verify ReserveHarness:certora/specs/Reserve.spec \
--packages openzeppelin-contracts=lib/openzeppelin-contracts/contracts \
--path . \
--solc solc8.15 \
--loop_iter 3 \
--optimistic_loop \
--staging \
--send_only \
$RULE  \
--msg "radicle Reserve-$RULE $MSG" \
--rule_sanity
