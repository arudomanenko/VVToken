const { Web3 } = require('web3');

// Event subscriptions require WebSocket — convert HTTP URL automatically
let rpcUrl = process.env.RPC_URL || 'ws://127.0.0.1:8545';
if (rpcUrl.startsWith('https://')) rpcUrl = rpcUrl.replace('https://', 'wss://');
else if (rpcUrl.startsWith('http://')) rpcUrl = rpcUrl.replace('http://', 'ws://');

const VOTING_ADDR = process.env.VOTING_ADDR;
const STAKING_ADDR = process.env.STAKING_ADDR;

if (!VOTING_ADDR) {
  console.error('Please set VOTING_ADDR env var to Voting contract address');
  process.exit(1);
}

const web3 = new Web3(new Web3.providers.WebsocketProvider(rpcUrl));

const votingAbi = [
  {
    anonymous: false,
    inputs: [
      { indexed: false, internalType: 'address', name: 'voter', type: 'address' },
      { indexed: false, internalType: 'uint256', name: 'votingPower', type: 'uint256' },
      { indexed: false, internalType: 'bytes32', name: 'id', type: 'bytes32' },
      { indexed: false, internalType: 'uint256', name: 'deadline', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'votingPowerThreshold', type: 'uint256' },
      { indexed: false, internalType: 'string', name: 'description', type: 'string' },
      { indexed: false, internalType: 'uint256', name: 'yesVotes', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'noVotes', type: 'uint256' },
      { indexed: false, internalType: 'bool', name: 'isOver', type: 'bool' }
    ],
    name: 'VoteDebug',
    type: 'event'
  }
];

const stakingAbi = [
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'user', type: 'address' },
      { indexed: true, internalType: 'uint256', name: 'index', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'amount', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'startTimestamp', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'endTimestamp', type: 'uint256' }
    ],
    name: 'StakeCreated',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'user', type: 'address' },
      { indexed: true, internalType: 'uint256', name: 'index', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'amount', type: 'uint256' }
    ],
    name: 'StakeUnstaked',
    type: 'event'
  }
];

const voting = new web3.eth.Contract(votingAbi, VOTING_ADDR);
const staking = STAKING_ADDR
  ? new web3.eth.Contract(stakingAbi, STAKING_ADDR)
  : null;

console.log(`Watching VoteDebug events on ${VOTING_ADDR} via ${rpcUrl}...`);
if (staking) {
  console.log(`Watching Staking events on ${STAKING_ADDR} via ${rpcUrl}...`);
}

// Web3.js v4: .on() returns undefined (no chaining) — store the sub first
const subVote = voting.events.VoteDebug({ fromBlock: 'latest' });

subVote.on('data', (event) => {
  const e = event.returnValues;
  console.log('--- VoteDebug ---');
  console.log('voter:      ', e.voter);
  console.log('votingPower:', e.votingPower.toString());
  console.log('id:         ', e.id);
  console.log('deadline:   ', e.deadline.toString());
  console.log('threshold:  ', e.votingPowerThreshold.toString());
  console.log('yesVotes:   ', e.yesVotes.toString());
  console.log('noVotes:    ', e.noVotes.toString());
  console.log('isOver:     ', e.isOver);
  console.log('description:', e.description);
  console.log();
});

subVote.on('error', (err) => {
  console.error('Error in event subscription:', err);
});

if (staking) {
  const subStakeCreated = staking.events.StakeCreated({ fromBlock: 'latest' });
  subStakeCreated.on('data', (event) => {
    const e = event.returnValues;
    console.log('--- StakeCreated ---');
    console.log('user:           ', e.user);
    console.log('index:          ', e.index.toString());
    console.log('amount:         ', e.amount.toString());
    console.log('startTimestamp: ', e.startTimestamp.toString());
    console.log('endTimestamp:   ', e.endTimestamp.toString());
    console.log();
  });
  subStakeCreated.on('error', (err) => {
    console.error('Error in StakeCreated subscription:', err);
  });

  const subStakeUnstaked = staking.events.StakeUnstaked({ fromBlock: 'latest' });
  subStakeUnstaked.on('data', (event) => {
    const e = event.returnValues;
    console.log('--- StakeUnstaked ---');
    console.log('user:   ', e.user);
    console.log('index:  ', e.index.toString());
    console.log('amount: ', e.amount.toString());
    console.log();
  });
  subStakeUnstaked.on('error', (err) => {
    console.error('Error in StakeUnstaked subscription:', err);
  });
}

