# This is a backup that works with UpdateReceiverStatesHarness.sol
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

#certoraRun  certora/harness/DripsHubHarness.sol \
#            src/Reserve.sol \
#            lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol \
#--verify DripsHubHarness:certora/specs/DripsHub.spec \
#--link  DripsHubHarness:reserve=Reserve \
certoraRun  certora/harness/UpdateReceiverStatesHarness.sol \
            src/Reserve.sol \
            lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol \
--verify UpdateReceiverStatesHarness:certora/specs/DripsHubBackup.spec \
--link  UpdateReceiverStatesHarness:reserve=Reserve \
--packages openzeppelin-contracts=lib/openzeppelin-contracts/contracts \
--path . \
--solc solc8.15 \
--loop_iter 3 \
--optimistic_loop \
--staging \
--send_only \
$RULE  \
--msg "radicle -$RULE $MSG" #\
#--debug

#--rule_sanity #\
#--debug

#--settings -depth=13 \
#--settings -divideNoRemainder=true \
#--optimistic_loop \
#--staging \
#--settings -t=800 \
#--settings -optimisticFallback=true --optimistic_loop \
#--settings -enableEqualitySaturation=false \


# additional parameters that might be helpful:
#--optimistic_loop
#--settings -optimisticFallback=true \
#--settings -enableEqualitySaturation=false
#--settings -simplificationDepth=10 \
#--settings -s=z3 \
#--setting -cegar=true \ #not working flag




#            src/AddressApp.sol \
#            src/Drips.sol \
#            src/Managed.sol \
#            src/Splits.sol \

# The goal of this script is the help run the tool
# without having to enter manually all the required
# parameters every time a test is executed
#
# The script should be executed from the terminal,
# with the project folder as the working folder
#
#
# The script can be run either with:
#
# 1) no parameters --> all the rules in the .spec file are tested
#    example:
#
#    ./certora/scripts/run.sh
#
#
# 2) with one parameter only --> the parameter states the rule name
#    example, when the rule name is "integrityOfDeposit":
#
#    ./certora/scripts/run.sh integrityOfDeposit
#
#
# 3) with two parameters:
#     - the first parameter is the rule name, as in 2)
#     - the second parameter is an optional message to help distinguish the rule
#       the second parameter should be encircled "with quotes"
#    example:
#
#    ./certora/scripts/run.sh integrityOfDeposit "user should get X for any deposit"
