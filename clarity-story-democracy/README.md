# Collaborative Story Writing Platform Smart Contract

## Overview
A decentralized platform for collaborative storytelling built on Stacks blockchain. This smart contract enables multiple authors to collectively create and develop stories while allowing community participation through voting on plot decisions.

## Features

### Story Management
- Create new stories with titles and categories
- Add chapters to existing stories
- Pause and resume story writing
- Mark stories as complete
- NFT-based story ownership

### Collaborative Writing
- Multiple contributor support with different roles
- Chapter-by-chapter story development
- Maximum of 50 chapters per story
- Contributor registry system

### Community Participation
- Create plot decision points with two options
- Community voting on plot decisions
- Configurable voting periods (24 hours to 10 days)
- Up to 1000 voters per decision
- Anti-duplicate voting protection

## Main Functions

### Story Creation and Management
- `create-new-story`: Initialize a new story with title and category
- `add-story-chapter`: Add a new chapter to an existing story
- `pause-story-writing`: Temporarily halt contributions to a story
- `resume-story-writing`: Resume accepting contributions
- `mark-story-complete`: Finalize a story

### Plot Decisions and Voting
- `create-plot-decision`: Create a new voting decision point
- `submit-plot-vote`: Cast a vote on a plot decision
- `check-voter-participation`: Verify if a user has voted

### Contributor Management
- `register-contributor`: Add new contributors with specific roles
- `get-contributor-status`: Check a contributor's role and status

### Read-Only Functions
- `get-story-details`: Retrieve story information
- `get-chapter-details`: Access chapter content
- `get-decision-details`: View plot decision details

## Technical Specifications

### Storage
The contract uses several data maps to store:
- Story details and metadata
- Chapter contents
- Plot decisions and voting data
- Contributor information
- Voter records

### Constants
- Maximum chapters per story: 50
- Minimum voting period: ~24 hours (144 blocks)
- Maximum voting period: ~10 days (1440 blocks)
- Maximum voters per decision: 1000

### Error Handling
Comprehensive error codes for various scenarios:
- Unauthorized access (100)
- Story not found (101)
- Story already exists (102)
- Voting period ended (103)
- Invalid vote option (104)
- Contributor rights issues (105)
- Chapter limit exceeded (106)
- Duplicate voter (107)
- Story paused (108)
- Invalid voting duration (109)
- Story completed (110)

## Events
The contract emits events for major actions:
- Story creation
- Chapter addition
- Decision creation
- Vote recording
- Story completion

## Security Features
- Owner-only administrative functions
- Contributor role verification
- Voting period enforcement
- Duplicate vote prevention
- Story pause mechanism

## Usage Notes
1. Story owners have special privileges for managing their stories
2. Contributors must be registered before adding chapters
3. Voting periods must be within the specified block range
4. Stories can be paused by owners or contract administrators
5. NFT tokens are minted to represent story ownership

## Limitations
- Chapter text limited to 1000 UTF-8 characters
- Story titles limited to 100 ASCII characters
- Category names limited to 20 ASCII characters
- Only two options per plot decision
- Fixed voting period constraints