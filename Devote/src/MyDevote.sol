// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;
contract MyDevote 
{
    struct Proposal
    {
        uint256 proposalId;
        string proposalName;
        string description;
        address owner;
        uint8[] voteOptions;
        uint256 endBlockNumber;
    }
    
    mapping(uint256 => Proposal) proposals;
    mapping(uint256 => mapping(address => uint256)) voteBalances;//id=>address=>balance, save the vote balances of each voter
    mapping(uint256 => mapping(address => uint8)) votes;//id=>address=>option, save the options of each voter
    mapping(uint256 => mapping(uint8=>uint256)) voteResults; //id=>option=>votecount, save the vote count of each option

    function createProposal(uint256 id, string memory name, string memory desc, uint8[] memory options, uint256 endBlock,
        address[] memory voters, uint256[] memory balances) public 
    {
        require(id!=0,"id not zero");

        Proposal storage p = proposals[id];
        require(p.proposalId==0,"proposal existed");
        require(options.length>0 && options.length<=10,"invalid options");
        require(voters.length>0,"voters not empty");
        require(voters.length==balances.length,"invalid balances");
        require(block.number<endBlock,"end block must gt current block");

        //使用uint256的移位和与运算判断选项是否有重复,限制是选项值不能超过256
        uint256 seen = 0;
        for(uint i=0;i<options.length;i++){
            uint8 opt = options[i];
            if (((seen >> opt) & 1) == 1) {
                revert("Duplicate");
            }
            seen |= (uint256(1) << opt);
        }
    
        //提案赋值并保存到storage   
        p.proposalId = id;
        p.proposalName = name; 
        p.description = desc;  
        p.owner = msg.sender;
        p.voteOptions = options;
        p.endBlockNumber = endBlock;

        for(uint i=0;i<voters.length;i++){
            voteBalances[id][voters[i]] = balances[i];
        }
    }

    function getProposal(uint256 id) external view returns (uint256, string memory, string memory, address, uint8[] memory, uint256) 
    {
        require(id!=0,"id not zero");
        Proposal storage p = proposals[id];
        require(p.proposalId>0,"Proposal not exist");

        return (p.proposalId, p.proposalName, p.description, p.owner, p.voteOptions, p.endBlockNumber);
    }
    
    function addDevote(uint256 pid, uint8 option) external 
    {
        require(pid!=0,"id not zero");
        Proposal storage p = proposals[pid];
        require(p.proposalId>0,"Proposal not exist");
        require(block.number<=p.endBlockNumber,"vote has finished");

        require(voteBalances[pid][msg.sender]>0,"voter balance must gt 0");

        bool found = false;
        for(uint i=0;i<p.voteOptions.length;i++){
            if(p.voteOptions[i]==option){
                found=true;
                break;
            }
        }
        require(found,"invalid option");
        
        require(votes[pid][msg.sender]==0,"you have voted");

        //save vote data
        votes[pid][msg.sender] = option;
        voteResults[pid][option] += voteBalances[pid][msg.sender];
    }
    
    function getDevote(uint256 pid) external view returns (uint8) 
    {
        require(pid!=0,"id not zero");
        Proposal storage p = proposals[pid];
        require(p.proposalId>0,"Proposal not exist");

        return (votes[pid][msg.sender]);
    }

    function getVoteResults(uint256 pid) external view returns (uint8[] memory, uint256[] memory) 
    {
        require(pid!=0,"id not zero");
        Proposal storage p = proposals[pid];
        require(p.proposalId>0,"Proposal not exist");
        require(block.number>p.endBlockNumber,"wait vote finished");

        uint256[] memory voteCounts = new uint256[](p.voteOptions.length);
        for(uint i=0;i<p.voteOptions.length;i++){
            voteCounts[i] = voteResults[pid][p.voteOptions[i]];
        }

        return (p.voteOptions,voteCounts);
    }
}