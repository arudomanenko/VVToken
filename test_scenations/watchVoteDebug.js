const { Web3 } = require('web3');

let rpcUrl = process.env.RPC_URL || 'ws://127.0.0.1:8545';
if (rpcUrl.startsWith('https://')) rpcUrl = rpcUrl.replace('https://', 'wss://');
else if (rpcUrl.startsWith('http://'))  rpcUrl = rpcUrl.replace('http://', 'ws://');

const VOTING_ADDR  = process.env.VOTING_ADDR;
const STAKING_ADDR = process.env.STAKING_ADDR;

if (!VOTING_ADDR) {
  console.error('Please set VOTING_ADDR env var');
  process.exit(1);
}

const web3 = new Web3(new Web3.providers.WebsocketProvider(rpcUrl));

const votingAbi = [
  {
    anonymous: false,
    inputs: [
      { indexed: true,  internalType: 'bytes32', name: 'voteId',               type: 'bytes32' },
      { indexed: false, internalType: 'uint256', name: 'deadline',             type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'votingPowerThreshold', type: 'uint256' },
      { indexed: false, internalType: 'string',  name: 'description',          type: 'string'  }
    ],
    name: 'VoteCreated',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true,  internalType: 'bytes32', name: 'voteId',      type: 'bytes32' },
      { indexed: true,  internalType: 'address', name: 'voter',       type: 'address' },
      { indexed: false, internalType: 'bool',    name: 'vote',        type: 'bool'    },
      { indexed: false, internalType: 'uint256', name: 'votingPower', type: 'uint256' }
    ],
    name: 'Voted',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true,  internalType: 'bytes32', name: 'voteId',   type: 'bytes32' },
      { indexed: false, internalType: 'string',  name: 'result',   type: 'string'  },
      { indexed: false, internalType: 'uint256', name: 'yesVotes', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'noVotes',  type: 'uint256' }
    ],
    name: 'VotingFinalized',
    type: 'event'
  }
];

const stakingAbi = [
  {
    anonymous: false,
    inputs: [
      { indexed: true,  internalType: 'address', name: 'user',           type: 'address' },
      { indexed: true,  internalType: 'uint256', name: 'index',          type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'amount',         type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'startTimestamp', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'endTimestamp',   type: 'uint256' }
    ],
    name: 'StakeCreated',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true,  internalType: 'address', name: 'user',   type: 'address' },
      { indexed: true,  internalType: 'uint256', name: 'index',  type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'amount', type: 'uint256' }
    ],
    name: 'StakeUnstaked',
    type: 'event'
  }
];

const ts = () => new Date().toISOString();

const voting = new web3.eth.Contract(votingAbi, VOTING_ADDR);
const staking = STAKING_ADDR ? new web3.eth.Contract(stakingAbi, STAKING_ADDR) : null;

console.log(`[${ts()}] Watching Voting events on ${VOTING_ADDR}`);
if (staking) console.log(`[${ts()}] Watching Staking events on ${STAKING_ADDR}`);

const subVoteCreated = voting.events.VoteCreated({ fromBlock: 'latest' });
subVoteCreated.on('data', (event) => {
  const e = event.returnValues;
  console.log(`[${ts()}] ── VoteCreated ──`);
  console.log(`  voteId:    ${e.voteId}`);
  console.log(`  deadline:  ${e.deadline}`);
  console.log(`  threshold: ${e.votingPowerThreshold}`);
  console.log(`  desc:      ${e.description}`);
  console.log();
});
subVoteCreated.on('error', (err) => console.error(`VoteCreated error: ${err.message}`));

const subVoted = voting.events.Voted({ fromBlock: 'latest' });
subVoted.on('data', (event) => {
  const e = event.returnValues;
  console.log(`[${ts()}] ── Voted ──`);
  console.log(`  voteId:      ${e.voteId}`);
  console.log(`  voter:       ${e.voter}`);
  console.log(`  vote:        ${e.vote ? 'YES' : 'NO'}`);
  console.log(`  votingPower: ${e.votingPower}`);
  console.log();
});
subVoted.on('error', (err) => console.error(`Voted error: ${err.message}`));

const subFinalized = voting.events.VotingFinalized({ fromBlock: 'latest' });
subFinalized.on('data', (event) => {
  const e = event.returnValues;
  console.log(`[${ts()}] ── VotingFinalized ──`);
  console.log(`  voteId:   ${e.voteId}`);
  console.log(`  result:   ${e.result}`);
  console.log(`  yesVotes: ${e.yesVotes}`);
  console.log(`  noVotes:  ${e.noVotes}`);
  console.log();
});
subFinalized.on('error', (err) => console.error(`VotingFinalized error: ${err.message}`));

if (staking) {
  const subStakeCreated = staking.events.StakeCreated({ fromBlock: 'latest' });
  subStakeCreated.on('data', (event) => {
    const e = event.returnValues;
    console.log(`[${ts()}] ── StakeCreated ──`);
    console.log(`  user:   ${e.user}`);
    console.log(`  index:  ${e.index}`);
    console.log(`  amount: ${e.amount}`);
    console.log(`  start:  ${e.startTimestamp}`);
    console.log(`  end:    ${e.endTimestamp}`);
    console.log();
  });
  subStakeCreated.on('error', (err) => console.error(`StakeCreated error: ${err.message}`));

  const subStakeUnstaked = staking.events.StakeUnstaked({ fromBlock: 'latest' });
  subStakeUnstaked.on('data', (event) => {
    const e = event.returnValues;
    console.log(`[${ts()}] ── StakeUnstaked ──`);
    console.log(`  user:   ${e.user}`);
    console.log(`  index:  ${e.index}`);
    console.log(`  amount: ${e.amount}`);
    console.log();
  });
  subStakeUnstaked.on('error', (err) => console.error(`StakeUnstaked error: ${err.message}`));
}

process.on('SIGTERM', () => {
  console.log(`[${ts()}] Watcher stopped.`);
  web3.currentProvider.disconnect();
  process.exit(0);
});
