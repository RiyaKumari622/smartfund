// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SmartFund
 * @dev A decentralized funding platform for project campaigns
 * @author SmartFund Team
 */
contract SmartFund {
    
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool fundsWithdrawn;
        mapping(address => uint256) contributions;
        address[] contributors;
    }
    
    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public constant PLATFORM_FEE_PERCENT = 2; // 2% platform fee
    address public owner;
    
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    
    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        campaignCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new funding campaign
     * @param _title Campaign title
     * @param _description Campaign description
     * @param _goalAmount Target funding amount in wei
     * @param _durationInDays Campaign duration in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        
        uint256 campaignId = campaignCounter;
        Campaign storage newCampaign = campaigns[campaignId];
        
        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goalAmount = _goalAmount;
        newCampaign.raisedAmount = 0;
        newCampaign.deadline = block.timestamp + (_durationInDays * 1 days);
        newCampaign.isActive = true;
        newCampaign.fundsWithdrawn = false;
        
        campaignCounter++;
        
        emit CampaignCreated(campaignId, msg.sender, _title, _goalAmount, newCampaign.deadline);
        
        return campaignId;
    }
    
    /**
     * @dev Core Function 2: Contribute funds to a campaign
     * @param _campaignId ID of the campaign to contribute to
     */
    function contributeToCampaign(uint256 _campaignId) 
        external 
        payable 
        campaignExists(_campaignId) 
    {
        require(msg.value > 0, "Contribution must be greater than 0");
        
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.isActive, "Campaign is not active");
        require(block.timestamp < campaign.deadline, "Campaign has expired");
        require(msg.sender != campaign.creator, "Creator cannot contribute to own campaign");
        
        // Track new contributors
        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }
        
        campaign.contributions[msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Withdraw funds from successful campaign or get refund
     * @param _campaignId ID of the campaign
     */
    function withdrawFunds(uint256 _campaignId) 
        external 
        campaignExists(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(!campaign.fundsWithdrawn, "Funds already withdrawn");
        
        // Case 1: Campaign creator withdrawing successful campaign funds
        if (msg.sender == campaign.creator) {
            require(block.timestamp >= campaign.deadline, "Campaign still active");
            require(campaign.raisedAmount >= campaign.goalAmount, "Goal not reached");
            
            uint256 platformFee = (campaign.raisedAmount * PLATFORM_FEE_PERCENT) / 100;
            uint256 creatorAmount = campaign.raisedAmount - platformFee;
            
            campaign.fundsWithdrawn = true;
            campaign.isActive = false;
            
            // Transfer platform fee to owner
            payable(owner).transfer(platformFee);
            
            // Transfer remaining funds to creator
            campaign.creator.transfer(creatorAmount);
            
            emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
        }
        // Case 2: Contributor requesting refund from failed campaign
        else {
            require(block.timestamp >= campaign.deadline, "Campaign still active");
            require(campaign.raisedAmount < campaign.goalAmount, "Campaign was successful");
            
            uint256 contributionAmount = campaign.contributions[msg.sender];
            require(contributionAmount > 0, "No contribution found");
            
            campaign.contributions[msg.sender] = 0;
            payable(msg.sender).transfer(contributionAmount);
            
            emit RefundIssued(_campaignId, msg.sender, contributionAmount);
        }
    }
    
    // View functions for frontend integration
    function getCampaignDetails(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            bool fundsWithdrawn
        ) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.fundsWithdrawn
        );
    }
    
    function getContribution(uint256 _campaignId, address _contributor) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (uint256) 
    {
        return campaigns[_campaignId].contributions[_contributor];
    }
    
    function getContributorCount(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (uint256) 
    {
        return campaigns[_campaignId].contributors.length;
    }
    
    // Emergency functions
    function emergencyPause(uint256 _campaignId) external onlyOwner campaignExists(_campaignId) {
        campaigns[_campaignId].isActive = false;
    }
    
    function emergencyUnpause(uint256 _campaignId) external onlyOwner campaignExists(_campaignId) {
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign has expired");
        campaigns[_campaignId].isActive = true;
    }
}
