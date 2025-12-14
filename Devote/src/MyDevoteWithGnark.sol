// SPDX-License-Identifier: MIT 
pragma solidity 0.8.30;

interface IGnarkVerifier
{
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata input // 公共输入
    ) external view returns (bool);
}

contract MyDevoteWithGnark 
{
    struct Proposal {
        uint256 id;
        string name;
        string description;
        address owner;
        uint8[] voteOptions; 
        uint256 endBlock;
        bool isFinalized;
        bytes32 tallyCommitment; // 加密的计票承诺（可选，用于二次揭晓）
    }

    mapping(uint256 => Proposal) proposals;
    mapping(uint256 => mapping(uint8 => uint256)) voteCountsOf; // id=>option=>count
    mapping(uint256 => bytes32) proposalTallyHash; // id=>tally hash
    mapping(uint256 => bool) nullifierSpent; //nullifierHash => bool

    IGnarkVerifier gnarkVerifier;

    event ProposalCreated(uint256 indexed id, string name, uint256 endBlock);
    event VoteCast(uint256 indexed proposalId,address indexed voter, uint256 nullifierHash);
    event TallyFinalized(uint256 indexed proposalId, uint256[] results);

    constructor(address _gnarkVerifier) {
        gnarkVerifier = IGnarkVerifier(_gnarkVerifier);
    }

    /*
    * @param id proposal id
    * @param option option index (0-255)
    * @param nullifierHash nullifier hash
    */
    function createProposal(uint256 pid, string memory name,string memory description, uint8[] memory options, uint256 endBlock) external 
    {
        require(pid!=0,"proposal id not zero");
        require(proposals[pid].owner == address(0), "Proposal already exists");
        require(options.length <= 256, "Too many options");
        require(block.number < endBlock, "End block must be in the future");
        proposals[pid] = Proposal({
            id: pid,
            name: name,
            description: description,
            owner: msg.sender,
            voteOptions: options,
            endBlock: endBlock,
            isFinalized: false,
            tallyCommitment: 0x0});
        emit ProposalCreated(pid, name, endBlock);
    }

    function castVoteWithZk(
        uint256 id, 
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256 _nullifierHash,uint8 _voteOption) external
    {
        require(id!=0,"proposal id not zero");
        Proposal storage p = proposals[id];
        require(p.owner!= address(0), "Proposal does not exist");
        require(block.number < p.endBlock, "Voting period has ended");
        require(!p.isFinalized, "Proposal finalized");
        require(_voteOption < p.voteOptions.length, "Invalid vote option");
        require(nullifierSpent[_nullifierHash] == false, "Nullifier already spent");

        // Verify option
        bool isValidOption = false;
        for (uint256 i = 0; i < p.voteOptions.length; i++) {
            if (p.voteOptions[i] == _voteOption) {
                isValidOption = true;
                break;
            }
        }
        require(isValidOption, "Invalid vote option");

        // Verify proof
        uint256[] memory publicInputs = new uint256[](4);
        publicInputs[0] = id;
        publicInputs[1] = _nullifierHash;
        publicInputs[2] = uint256(_voteOption);
        publicInputs[3] = uint256(uint160(msg.sender)); // 可选：增加额外验证
        bool proofValid = gnarkVerifier.verifyProof(a, b, c, publicInputs);
        require(proofValid, "Invalid ZK proof");

        nullifierSpent[_nullifierHash] = true;
        voteCountsOf[id][_voteOption] += 1;
        
        emit VoteCast(id, msg.sender, _nullifierHash);
    }

}