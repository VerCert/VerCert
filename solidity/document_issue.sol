// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract DocumentStorage is Initializable, UUPSUpgradeable, ReentrancyGuard {
  struct Document {
    bytes32 sha256Hash;
    string ipfsCID;
  }

  address[3] private owners;

  // Authorized issuers and revokers using index-based tracking (gas optimized)
  mapping(address => uint256) private issuerIndex;
  address[] private issuerList;

  mapping(address => uint256) private revokerIndex;
  address[] private revokerList;

  mapping(uint256 => Document[]) private _userDocuments;

  event DocumentStored(
    uint256 indexed userId,
    bytes32 sha256Hash,
    string ipfsCID
  );
  event DocumentRevoked(
    uint256 indexed userId,
    bytes32 sha256Hash,
    string ipfsCID
  );
  event IssuerAdded(address indexed issuer);
  event IssuerRemoved(address indexed issuer);
  event RevokerAdded(address indexed revoker);
  event RevokerRemoved(address indexed revoker);

  modifier onlyOwners() {
    require(
      msg.sender == owners[0] ||
        msg.sender == owners[1] ||
        msg.sender == owners[2],
      'Not an owner'
    );
    _;
  }

  function initialize(address _owner2, address _owner3) public initializer {
    require(msg.sender == tx.origin, 'Only the deployer can initialize');
    owners[0] = msg.sender;
    owners[1] = _owner2;
    owners[2] = _owner3;
    __UUPSUpgradeable_init();
  }

  function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyOwners
  {}

  // Add authorized issuer (optimized)
  function addAuthorizedIssuer(address issuer) external onlyOwners {
    require(
      issuerIndex[issuer] == 0 &&
        (issuerList.length == 0 || issuerList[0] != issuer),
      'User already authorized'
    );
    issuerIndex[issuer] = issuerList.length + 1; // Store index (1-based)
    issuerList.push(issuer);
    emit IssuerAdded(issuer);
  }

  // Remove authorized issuer (optimized)
  function removeAuthorizedIssuer(address issuer) external onlyOwners {
    require(issuerIndex[issuer] > 0, 'User is not authorized');

    uint256 index = issuerIndex[issuer] - 1; // Convert to 0-based index
    uint256 lastIndex = issuerList.length - 1;

    if (index != lastIndex) {
      issuerList[index] = issuerList[lastIndex];
      issuerIndex[issuerList[index]] = index + 1; // Update swapped index
    }

    issuerList.pop();
    delete issuerIndex[issuer];
    emit IssuerRemoved(issuer);
  }

  // Add authorized revoker (optimized)
  function addAuthorizedRevoker(address revoker) external onlyOwners {
    require(
      revokerIndex[revoker] == 0 &&
        (revokerList.length == 0 || revokerList[0] != revoker),
      'User already authorized'
    );
    revokerIndex[revoker] = revokerList.length + 1; // Store index (1-based)
    revokerList.push(revoker);
    emit RevokerAdded(revoker);
  }

  // Remove authorized revoker (optimized)
  function removeAuthorizedRevoker(address revoker) external onlyOwners {
    require(revokerIndex[revoker] > 0, 'User is not authorized');

    uint256 index = revokerIndex[revoker] - 1; // Convert to 0-based index
    uint256 lastIndex = revokerList.length - 1;

    if (index != lastIndex) {
      revokerList[index] = revokerList[lastIndex];
      revokerIndex[revokerList[index]] = index + 1; // Update swapped index
    }

    revokerList.pop();
    delete revokerIndex[revoker];
    emit RevokerRemoved(revoker);
  }

  // List all authorized issuers
  function getAllAuthorizedIssuers() external view returns (address[] memory) {
    return issuerList;
  }

  // List all authorized revokers
  function getAllAuthorizedRevokers() external view returns (address[] memory) {
    return revokerList;
  }

  // Store a document (allowed for owners or authorized issuers) with frontrunning prevention
  function storeDocument(
    uint256 userId,
    bytes32 sha256Hash,
    string memory ipfsCID
  ) external nonReentrant {
    require(
      issuerIndex[msg.sender] > 0 ||
        msg.sender == owners[0] ||
        msg.sender == owners[1] ||
        msg.sender == owners[2],
      'Not authorized to store'
    );

    // Prevent duplicate storage of the same document
    Document[] storage docs = _userDocuments[userId];
    for (uint256 i = 0; i < docs.length; i++) {
      require(docs[i].sha256Hash != sha256Hash, 'Document already stored');
    }

    _userDocuments[userId].push(Document(sha256Hash, ipfsCID));
    emit DocumentStored(userId, sha256Hash, ipfsCID);
  }

  // Revoke a document securely with reentrancy guard
  function revokeDocument(uint256 userId, bytes32 sha256Hash)
    external
    nonReentrant
  {
    require(
      revokerIndex[msg.sender] > 0 ||
        msg.sender == owners[0] ||
        msg.sender == owners[1] ||
        msg.sender == owners[2],
      'Not authorized to revoke'
    );

    Document[] storage docs = _userDocuments[userId];
    for (uint256 i = 0; i < docs.length; i++) {
      if (docs[i].sha256Hash == sha256Hash) {
        emit DocumentRevoked(userId, docs[i].sha256Hash, docs[i].ipfsCID);
        docs[i] = docs[docs.length - 1];
        docs.pop();
        break;
      }
    }
  }

  // Get all documents for a user
  function getDocuments(uint256 userId)
    public
    view
    returns (bytes32[] memory, string[] memory)
  {
    Document[] storage docs = _userDocuments[userId];
    bytes32[] memory hashes = new bytes32[](docs.length);
    string[] memory cids = new string[](docs.length);
    for (uint256 i = 0; i < docs.length; i++) {
      hashes[i] = docs[i].sha256Hash;
      cids[i] = docs[i].ipfsCID;
    }
    return (hashes, cids);
  }

  // Get the number of documents for a user
  function getDocumentCount(uint256 userId) public view returns (uint256) {
    return _userDocuments[userId].length;
  }
}
