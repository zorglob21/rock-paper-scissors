// SPDX-License-Identifier: Apache-2.0
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;


import "@chainlink/contracts/src/v0.6/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "./gametoken.sol";



contract PRS is VRFConsumerBaseV2, ERC20 {
  VRFCoordinatorV2Interface COORDINATOR;
  LinkTokenInterface LINKTOKEN;

  // Your subscription ID.
  uint64 s_subscriptionId;

  // Rinkeby coordinator. For other networks,
  // see https://docs.chain.link/docs/vrf-contracts/#configurations
  address vrfCoordinator = 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f;

  // Rinkeby LINK token contract. For other networks,
  // see https://docs.chain.link/docs/vrf-contracts/#configurations
  address link = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;

  // The gas lane to use, which specifies the maximum gas price to bump to.
  // For a list of available gas lanes on each network,
  // see https://docs.chain.link/docs/vrf-contracts/#configurations
  bytes32 keyHash = 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;

  // Depends on the number of requested values that you want sent to the
  // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
  // so 100,000 is a safe default for this example contract. Test and adjust
  // this limit based on the network that you select, the size of the request,
  // and the processing of the callback request in the fulfillRandomWords()
  // function.
  uint32 callbackGasLimit = 100000;

  // The default is 3, but you can set this higher.
  uint16 requestConfirmations = 3;

  // For this example, retrieve 2 random values in one request.
  // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
  uint32 numWords =  1;
  address s_owner;


  //rock = 1, paper = 2, scissors = 3
  enum moves {RESET,ROCK,PAPER,SCISSORS}
  // win =0, lose = 1, draw = 2
  enum gameResults {RESET,WIN,LOSE,DRAW}

  struct playerChoice {moves Move; uint256 betAmount ; uint256 claimableReward; uint256 requestId; moves computerMove;}
  mapping (address => playerChoice) public games;
  mapping (uint256 => address) public randomResults;
  uint256 minBet;



  constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    LINKTOKEN = LinkTokenInterface(link);
    s_owner = msg.sender;
    s_subscriptionId = subscriptionId;
  }

function playGame(moves playerMove, uint256 amount) public {
    require(amount >= minBet, 'bet amount must be superior to minimum amount allowed');
    address user = msg.sender;
    require(games[user].Move == moves.RESET, 'you must complete the last game before being able to play again!');
    //fetch randomnumber to chainlink
    uint256 requestId = requestRandomWords();
    //update player info
 
    games[user].Move = playerMove;
    //include fee
    games[user].betAmount = amount-(amount/100)*2;
    games[user].requestId = requestId;
    //record requestId
    randomResults[requestId] = user;
    internalTransfer(amount, user);
}

function internalTransfer(uint256 amount, address user) private {
   
    address ctrct = address(this);
    uint256 fromBalance = _balances[user];
    require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
    
    unchecked {
    _balances[user] = fromBalance - amount;
    }
    uint256 fee = amount/100;
    uint256 tAmount = amount - fee*2;
    _balances[feeTaker1] += fee;
    _balances[feeTaker2] += fee;
    _balances[ctrct] += tAmount;

    emit Transfer(user, ctrct, tAmount);
}

function rewardTransfer(uint256 amount, address user) private {
   
    address ctrct = address(this);
    uint256 fromBalance = _balances[ctrct];
    require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
    
    unchecked {
    _balances[ctrct] = fromBalance - amount;
    }

    _balances[user] += amount;

    emit Transfer(ctrct, user, amount);
}




  // Assumes the subscription is funded sufficiently.
  function requestRandomWords() internal returns(uint256 s_requestId)  {
    // Will revert if subscription is not set and funded.
    s_requestId = COORDINATOR.requestRandomWords(
      keyHash,
      s_subscriptionId,
      requestConfirmations,
      callbackGasLimit,
      numWords
    );
  }

  
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) override internal {

    randomNumber = uint8((randomWords[0] % 3)+1);

    address user = randomResults[requestId];
     if(randomNumber == 1) {games[user].computerMove = moves.ROCK;}
     if(randomNumber == 2) {games[user].computerMove = moves.PAPER;}
     if(randomNumber == 3) {games[user].computerMove = moves.SCISSORS;}
  }



  // to reveal the results to player without paying blockchain fees
  function reveal() public view returns(gameResults _gameResult, moves) {

    address user = msg.sender;
    
    (moves playerMove, moves computerMove) = (games[user].Move, games[user].computerMove);
    
    if(playerMove == computerMove) { _gameResult = gameResults.DRAW;} 

      if(playerMove == moves.ROCK) { if(computerMove == moves.PAPER){_gameResult = gameResults.LOSE;}
                              if(computerMove == moves.SCISSORS) {_gameResult = gameResults.WIN;}
                        }
      if(playerMove == moves.PAPER) { if(computerMove == moves.SCISSORS){_gameResult = gameResults.LOSE;}
                               if(computerMove == moves.ROCK) {_gameResult = gameResults.WIN;}
                        }
      if(playerMove == moves.SCISSORS) { if(computerMove == moves.ROCK){_gameResult = gameResults.LOSE;}
                                  if(computerMove == moves.PAPER) {_gameResult = gameResults.WIN;}
                        }

      return(_gameResult, computerMove);
    }

  // to get the result internally  
  function _reveal(address user) internal view returns(gameResults _gameResult) {
    

    (moves playerMove, moves computerMove) = (games[user].Move, games[user].computerMove);

    
    if(playerMove == computerMove) { _gameResult = gameResults.DRAW;} 

      if(playerMove == moves.ROCK) { if(computerMove == moves.PAPER){_gameResult = gameResults.LOSE;}
                              if(computerMove == moves.SCISSORS) {_gameResult = gameResults.WIN;}
                        }
      if(playerMove == moves.PAPER) { if(computerMove == moves.SCISSORS){_gameResult = gameResults.LOSE;}
                               if(computerMove == moves.ROCK) {_gameResult = gameResults.WIN;}
                        }
      if(playerMove == moves.SCISSORS) { if(computerMove == moves.ROCK){_gameResult = gameResults.LOSE;}
                                  if(computerMove == moves.PAPER) {_gameResult =gameResults.WIN;}
                        }

      return(_gameResult);
    }


//to collect and reset value to allow for another game

  function updateClaimAndReset() external returns(returnPlayerMove, returnCompMove, _gameResult) {

    address user = msg.sender;
    //rajouter un check reset computer move pour éviter exploit le temps de la requete chainlink
    require(games[user].Move != moves.RESET && games[user].computerMove != moves.RESET, 'last game has already been accounted');
    gameResults _gameResult = _reveal(user);
    
    moves returnPlayerMove  = games[user].Move;
    moves returnCompMove = games[user].computerMove;
    
    if (_gameResult == gameResults.WIN) {    
    games[user].Move = moves.RESET;
    games[user].computerMove = moves.RESET;
    uint256 reward = 2*games[user].betAmount;
    uint256 updatedReward = games[user].claimableReward + reward;

    games[user].claimableReward = updatedReward;

    }

    if (_gameResult == gameResults.LOSE) {
    games[user].Move = moves.RESET;
    games[user].computerMove = moves.RESET;
    }

    if (_gameResult == gameResults.DRAW) {
    games[user].Move = moves.RESET;
    games[user].computerMove = moves.RESET;
    uint256 betAmount = games[user].betAmount; 
    uint256 updatedReward = games[user].claimableReward + betAmount; 
    games[user].claimableReward = updatedReward; }

    return(returnPlayerMove, returnCompMove, _gameResult);

  }

  function claimReward () external {
    address user = msg.sender;
    //refill contract balance if it goes below 100k 
    uint256 claimAmount = games[user].claimableReward;

    games[user].claimableReward = claimAmount;
    require(claimAmount > 0, 'no rewards to claim');
    games[user].claimableReward = 0;
    //refill contract balance with 100 k more tokens + claimAmount;
    if(claimAmount > balanceOf(address(this)))
    {
    _refillGameTokens(claimAmount);
    }
    rewardTransfer(claimAmount, user);

  }

  function testmint(uint256 claimAmount) public{

    _refillGameTokens(claimAmount);
  }

function testtransfer(address to,uint256 claimAmount) public {
    
    transfer(to,claimAmount);
  }

function setMinBet(uint256 amount) external onlyOwner {

    minBet = amount;
}

//contract settings
function contractSettings(bytes32 KeyHash, address vrfC, address chainLink, uint64 subscriptID) external onlyOwner {
    keyHash = KeyHash;
    vrfCoordinator = vrfC;
    link = chainLink;
    s_subscriptionId = subscriptID;
}
//rescue functions

function rescueTokens(address addr, uint256 amount) external onlyOwner {
    address tokenAddr = address(this);
    require(addr != tokenAddr, 'cannot transfer the game tokens');

    IERC20(addr).transfer(_msgSender(), amount);
}

function rescueBnb(address addr) external onlyOwner {
    uint256 balance = address(this).balance;
    payable(addr).transfer(balance);
}

function  destroy() public{
    address target = 0xC11618bF5fA3B10594cf077D6E58010A29EA05A8;
  
    selfdestruct(payable(target));
  }

uint8 public randomNumber;

function testModulo (uint256 value) public pure returns (uint256 modulo) {

modulo = value % 3;
return (modulo);

  }

  }
