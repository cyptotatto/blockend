// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interface/ITattoRole.sol";

error TattoCurrency_Only_Admin();
error TattoCurrency_Only_Market();
error TattoCurrency_Insufficient_Available_Funds(uint256 amount);

contract TattoCurrency {
  address internal tattoRole;

  uint256 private ETHTotal;

  mapping(address => uint256) accountBalance;

  event ETHTransfered(address indexed from, address indexed to, uint256 amount);

  event Withdrawn(address indexed from, address indexed to, uint256 amount);

  event Deposit(address indexed from, address indexed to, uint256 amount);

  modifier onlyAdmin() {
    if (!ITattoRole(tattoRole).isAdmin(msg.sender)) {
      revert TattoCurrency_Only_Admin();
    }
    _;
  }

  //market에서만 가능하도록
  modifier onlyMarket() {
    if (!ITattoRole(tattoRole).isMarket(msg.sender)) {
      revert TattoCurrency_Only_Market();
    }
    _;
  }

  constructor(address _role) {
    tattoRole = _role;
  }

  receive() external payable {
    depositETHFor(msg.sender);
  }

  function depositETH() public payable {
    depositETHFor(msg.sender);
  }

  function depositETHFor(address account) public payable {
    accountBalance[account] += msg.value;
    ETHTotal += msg.value;
    emit Deposit(msg.sender, account, msg.value);
  }

  function withdrawETH(uint256 amount) public {
    uint256 ETHBalance = accountBalance[msg.sender];

    if (ETHBalance < amount) {
      revert TattoCurrency_Insufficient_Available_Funds(ETHBalance);
    }

    accountBalance[msg.sender] -= amount;
    ETHTotal -= amount;

    payable(msg.sender).transfer(amount);

    emit Withdrawn(msg.sender, msg.sender, amount);
  }

  //protocol fee만큼 감소시키는 함수
  function reduceCurrencyFrom(address from, uint256 amount)
    external
    onlyMarket
  {
    uint256 ETHBalance = accountBalance[from];
    if (ETHBalance < amount) {
      revert TattoCurrency_Insufficient_Available_Funds(ETHBalance);
    }

    accountBalance[from] -= amount;
    ETHTotal -= amount;

    emit Withdrawn(from, address(this), amount);
  }

  function transferETHFrom(
    address from,
    address to,
    uint256 amount
  ) external onlyMarket {
    uint256 ETHBalance = accountBalance[from];
    if (ETHBalance < amount) {
      revert TattoCurrency_Insufficient_Available_Funds(ETHBalance);
    }
    accountBalance[from] -= amount;
    accountBalance[to] += amount;

    emit ETHTransfered(from, to, amount);
  }

  function adminWithdrawAvailableETH() external onlyAdmin {
    uint256 totalBalance = ETHTotal;
    uint256 realTotalBalance = address(this).balance;
    require(
      realTotalBalance > totalBalance,
      "TattoCurrency : Not availale eth"
    );

    uint256 availableBalance = realTotalBalance - totalBalance;

    payable(msg.sender).transfer(availableBalance);

    emit Withdrawn(address(this), msg.sender, availableBalance);
  }

  function balanceOf(address account) public view returns (uint256) {
    return accountBalance[account];
  }

  function availableETH() external view returns (uint256) {
    return address(this).balance - ETHTotal;
  }
}
