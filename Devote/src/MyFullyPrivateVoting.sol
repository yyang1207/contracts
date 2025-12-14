// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IVerifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata input
    ) external view returns (bool);
}

/**
 * @title ITallyVerifier
 * @notice 用于验证“计票解密正确性”零知识证明的接口。
 *         该证明证实：提交的明文票数，确实是链上加密承诺tallyCommitment的正确解密结果。
 */
interface ITallyVerifier {
    /**
     * @notice 验证解密结果正确性的零知识证明
     * @param _proofA Groth16证明的A点坐标（uint256[2]）
     * @param _proofB Groth16证明的B点坐标（uint256[2][2]）
     * @param _proofC Groth16证明的C点坐标（uint256[2]）
     * @param _publicInputs 公共输入数组，必须严格按以下顺序[citation:1]：
     *         _publicInputs[0] = tallyCommitmentX (加密承诺的X坐标)
     *         _publicInputs[1] = tallyCommitmentY (加密承诺的Y坐标)
     *         _publicInputs[2] = yesVotes (明文“赞成”票数)
     *         _publicInputs[3] = noVotes  (明文“反对”票数)
     * @return 如果证明有效则返回 true，否则返回 false
     */
    function verifyProof(
        uint256[2] calldata _proofA,
        uint256[2][2] calldata _proofB,
        uint256[2] calldata _proofC,
        uint256[] calldata _publicInputs
    ) external view returns (bool);
}

contract FullyPrivateVoting {
    // ========== 状态变量 ==========
    // 提案结构体（不包含任何个体投票信息）
    struct Proposal {
        uint256 id;
        string name;
        uint256[2] tallyCommitment; // 同态加密的累加承诺（椭圆曲线点）
        uint256 endBlock;
        bool isFinalized;
        uint256 totalNullifiers; // 已投票数量（防重复但不泄露身份）
        uint256 finalYesVotes; // 新增：存储最终结果
        uint256 finalNoVotes;  // 新增
    }
    mapping(uint256 => Proposal) private proposals;

    // 防止重复投票的Nullifier映射（核心隐私保护）
    mapping(uint256 => bool) private nullifierSpent; // nullifierHash => spent

    // 两个验证器：一个用于投票，一个用于计票揭晓
    IVerifier private votingVerifier;
    ITallyVerifier private tallyVerifier;

    // ========== 事件 ==========
    event ProposalCreated(uint256 indexed id, string name);
    event VoteSubmitted(uint256 indexed proposalId, uint256 nullifierHash);
    event TallyFinalized(uint256 indexed proposalId, uint256 yesVotes, uint256 noVotes);

    // ========== 核心函数 ==========

    /**
     * 创建提案
     * @param _id 提案ID
     * @param _name 提案名称
     * @param _endBlock 投票截止区块
     * @param _initialTallyCommitment 初始计票承诺（通常为加密的0）
     */
    function createProposal(
        uint256 _id,
        string calldata _name,
        uint256 _endBlock,
        uint256[2] calldata _initialTallyCommitment
    ) external {
        require(proposals[_id].id == 0, "Proposal exists");
        proposals[_id] = Proposal({
            id: _id,
            name: _name,
            tallyCommitment: _initialTallyCommitment,
            endBlock: _endBlock,
            isFinalized: false,
            totalNullifiers: 0,
            finalYesVotes: 0,
            finalNoVotes: 0
        });
        emit ProposalCreated(_id, _name);
    }

    /**
     * 提交隐私投票（核心）
     * @param _proposalId 提案ID
     * @param _proof 零知识证明（证明我是组成员且投票有效）
     * @param _nullifierHash 唯一作废标识符
     * @param _newTallyCommitment 投票后新的累加承诺（同态加密累加）
     */
    function submitVote(
        uint256 _proposalId,
        uint256[8] calldata _proof, // Groth16证明通常为8个uint256
        uint256 _nullifierHash,
        uint256[2] calldata _newTallyCommitment
    ) external {
        Proposal storage p = proposals[_proposalId];
        require(block.number < p.endBlock, "Voting ended");
        require(!nullifierSpent[_nullifierHash], "Vote already cast");

        // 公共输入：提案ID， nullifier, 新旧累加承诺
        uint256[] memory publicInputs = new uint256[](6);
        publicInputs[0] = _proposalId;
        publicInputs[1] = _nullifierHash;
        publicInputs[2] = p.tallyCommitment[0];
        publicInputs[3] = p.tallyCommitment[1];
        publicInputs[4] = _newTallyCommitment[0];
        publicInputs[5] = _newTallyCommitment[1];

        // 验证零知识证明的有效性
        bool proofValid = votingVerifier.verifyProof(
            [_proof[0], _proof[1]],
            [[_proof[2], _proof[3]], [_proof[4], _proof[5]]],
            [_proof[6], _proof[7]],
            publicInputs
        );
        require(proofValid, "Invalid ZK proof");

        // 更新状态（这是整个合约中唯一更新计票的地方）
        nullifierSpent[_nullifierHash] = true;
        p.tallyCommitment = _newTallyCommitment; // 更新为新的加密累加值
        p.totalNullifiers += 1;

        emit VoteSubmitted(_proposalId, _nullifierHash);
    }

    /**
     * 最终化计票结果（二次揭晓）
     * @param _proposalId 提案ID
     * @param _tallyProof 计票正确性的零知识证明
     * @param _yesVotes 是票数（明文结果）
     * @param _noVotes 否票数（明文结果）
     */
    function finalizeTally(
        uint256 _proposalId,
        uint256[8] calldata _tallyProof,
        uint256 _yesVotes,
        uint256 _noVotes
    ) external 
    {
        Proposal storage p = proposals[_proposalId];
        require(block.number >= p.endBlock, "Voting not ended");
        require(!p.isFinalized, "Already finalized");

        // 公共输入：最终计票承诺和明文结果
        uint256[] memory publicInputs = new uint256[](4);
        publicInputs[0] = p.tallyCommitment[0];
        publicInputs[1] = p.tallyCommitment[1];
        publicInputs[2] = _yesVotes;
        publicInputs[3] = _noVotes;

        // 验证计票解密证明
        bool tallyValid = tallyVerifier.verifyProof(
            [_tallyProof[0], _tallyProof[1]],
            [[_tallyProof[2], _tallyProof[3]], [_tallyProof[4], _tallyProof[5]]],
            [_tallyProof[6], _tallyProof[7]],
            publicInputs
        );
        require(tallyValid, "Invalid tally proof");

        p.isFinalized = true;
        p.finalYesVotes = _yesVotes; // 关键：存储结果
        p.finalNoVotes = _noVotes;

        emit TallyFinalized(_proposalId, _yesVotes, _noVotes);
    }

    // 查询最终结果（仅在finalize后有效）
    function getResult(uint256 _proposalId) external view returns (uint256 yesVotes, uint256 noVotes, bool finalized) 
    {
        Proposal storage p = proposals[_proposalId];
        if(p.isFinalized) 
        {
            // 已揭晓：返回存储的结果
            return (p.finalYesVotes, p.finalNoVotes, true);
        } 
        else 
        {
            // 未揭晓：返回0和未完成状态
            return (0, 0, false);
        }
    }
}