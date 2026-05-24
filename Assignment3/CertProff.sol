// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

/*
    Certproff Academic Credential Verification System

    Contracts Included:
    - Institution
    - Registry
    - Verification
    - CredentialToken

    Features:
    - Approve/remove institutions
    - Issue academic certificates
    - Update certificate status
    - Verify credentials
    - Mint credential NFTs
*/

/// -----------------------------------------------------------------------
/// ENUMS
/// -----------------------------------------------------------------------

/*
    Enum used to represent the current state of a certificate.
*/
enum CertificateStatus {
    Active,
    Revoked,
    Corrected,
    Replaced
}

/// -----------------------------------------------------------------------
/// INSTITUTION CONTRACT
/// -----------------------------------------------------------------------

/*
    This contract manages which universities/institutions
    are allowed to issue credentials on the platform.
*/
contract Institution {

    // Address of the platform administrator
    address public admin;

    /*
        Mapping that stores whether an institution
        is approved or not.

        institution address => true/false
    */
    mapping(address => bool) public approvedInstitutions;

    // Event emitted when an institution is approved
    event InstitutionApproved(address institution);

    // Event emitted when an institution is removed
    event InstitutionRemoved(address institution);

    /*
        Modifier that restricts access
        so only the admin can execute functions.
    */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not system admin");
        _;
    }

    /*
        Constructor runs once when the contract
        is first deployed.

        The deployer becomes the system admin.
    */
    constructor() {
        admin = msg.sender;
    }

    /*
        approveInstitution()

        Allows the admin to approve a university
        so it can issue certificates.
    */
    function approveInstitution(address institution) public onlyAdmin {

        // Mark institution as approved
        approvedInstitutions[institution] = true;

        // Emit blockchain event
        emit InstitutionApproved(institution);
    }

    /*
        removeInstitution()

        Allows the admin to revoke an institution's
        permission to issue credentials.
    */
    function removeInstitution(address institution) public onlyAdmin {

        // Remove approval status
        approvedInstitutions[institution] = false;

        // Emit blockchain event
        emit InstitutionRemoved(institution);
    }

    /*
        isApproved()

        Returns whether a university is approved.
        Used by other contracts for access control.
    */
    function isApproved(address institution) public view returns (bool) {

        return approvedInstitutions[institution];
    }
}

/// -----------------------------------------------------------------------
/// REGISTRY CONTRACT
/// -----------------------------------------------------------------------

/*
    Main contract responsible for storing
    academic credential information.
*/
contract Registry {

    // Reference to Institution contract
    Institution public institutionContract;

    /*
        Constructor stores the deployed
        Institution contract address.
    */
    constructor(address institutionAddress) {

        institutionContract = Institution(institutionAddress);
    }

    /*
        Structure representing a credential.
    */
    struct Credential {

        // Unique credential identifier
        string credentialID;

        // Qualification name/title
        string qualificationTitle;

        // University/institution name
        string issuingInstitution;

        // Time credential was issued
        uint256 issueDate;

        // Current certificate status
        CertificateStatus status;

        // Graduate wallet address
        address graduateAddress;

        // Tracks whether credential exists
        bool exists;
    }

    /*
        Mapping storing credentials.

        credentialID => Credential
    */
    mapping(string => Credential) private credentials;

    // Event emitted when a certificate is issued
    event CertificateIssued(
        string credentialID,
        string qualificationTitle,
        string issuingInstitution,
        address graduate
    );

    // Event emitted when credential status changes
    event StatusUpdated(
        string credentialID,
        CertificateStatus status
    );

    /*
        Modifier that only allows approved
        institutions to execute functions.
    */
    modifier onlyApprovedInstitution() {

        require(
            institutionContract.isApproved(msg.sender),
            "Institution not approved"
        );

        _;
    }

    /*
        issueCertificate()

        Creates a brand-new academic credential
        and stores it permanently on the blockchain.
    */
    function issueCertificate(
        string memory _credentialID,
        string memory _qualificationTitle,
        string memory _issuingInstitution,
        address _graduateAddress
    ) public onlyApprovedInstitution {

        /*
            Ensure credential ID has not
            already been used.
        */
        require(
            !credentials[_credentialID].exists,
            "Credential already exists"
        );

        /*
            Store credential information
            inside blockchain storage.
        */
        credentials[_credentialID] = Credential({
            credentialID: _credentialID,
            qualificationTitle: _qualificationTitle,
            issuingInstitution: _issuingInstitution,
            issueDate: block.timestamp,
            status: CertificateStatus.Active,
            graduateAddress: _graduateAddress,
            exists: true
        });

        /*
            Emit event for frontend apps
            and blockchain logs.
        */
        emit CertificateIssued(
            _credentialID,
            _qualificationTitle,
            _issuingInstitution,
            _graduateAddress
        );
    }

    /*
        updateStatus()

        Allows an institution to change
        the status of an existing credential.

        Example:
        - Revoked
        - Corrected
        - Replaced
    */
    function updateStatus(
        string memory _credentialID,
        CertificateStatus _status
    ) public onlyApprovedInstitution {

        // Ensure credential exists first
        require(
            credentials[_credentialID].exists,
            "Credential does not exist"
        );

        // Update stored status
        credentials[_credentialID].status = _status;

        // Emit blockchain event
        emit StatusUpdated(_credentialID, _status);
    }

    /*
        getCredential()

        Returns all stored information
        about a credential.

        Used by the Verification contract
        and frontend applications.
    */
    function getCredential(
        string memory _credentialID
    )
        public
        view
        returns (
            string memory,
            string memory,
            string memory,
            uint256,
            CertificateStatus,
            address
        )
    {
        // Ensure credential exists
        require(
            credentials[_credentialID].exists,
            "Credential does not exist"
        );

        // Load credential into memory
        Credential memory c = credentials[_credentialID];

        // Return credential information
        return (
            c.credentialID,
            c.qualificationTitle,
            c.issuingInstitution,
            c.issueDate,
            c.status,
            c.graduateAddress
        );
    }
}

/// -----------------------------------------------------------------------
/// VERIFICATION CONTRACT
/// -----------------------------------------------------------------------

/*
    Contract used by employers, universities,
    or third parties to verify credentials.
*/
contract Verification {

    // Reference to Registry contract
    Registry public registry;

    /*
        Constructor stores Registry
        contract address.
    */
    constructor(address registryAddress) {

        registry = Registry(registryAddress);
    }

    /*
        Structure returned during verification.
    */
    struct VerificationResult {

        string credentialID;
        string qualificationTitle;
        string issuingInstitution;
        uint256 issueDate;
        CertificateStatus status;

        // Indicates if certificate is valid
        bool valid;
    }

    /*
        verifyCredential()

        Retrieves credential information
        and determines whether it is valid.

        A credential is valid only if
        its status is Active.
    */
    function verifyCredential(
        string memory _credentialID
    )
        public
        view
        returns (VerificationResult memory)
    {

        /*
            Retrieve credential information
            from Registry contract.
        */
        (
            string memory credentialID,
            string memory qualificationTitle,
            string memory issuingInstitution,
            uint256 issueDate,
            CertificateStatus status,

        ) = registry.getCredential(_credentialID);

        /*
            Determine whether credential
            should be considered valid.
        */
        bool isValid = (status == CertificateStatus.Active);

        /*
            Return verification result.
        */
        return VerificationResult({
            credentialID: credentialID,
            qualificationTitle: qualificationTitle,
            issuingInstitution: issuingInstitution,
            issueDate: issueDate,
            status: status,
            valid: isValid
        });
    }
}

/// -----------------------------------------------------------------------
/// CREDENTIAL TOKEN CONTRACT
/// -----------------------------------------------------------------------

/*
    Represents academic credentials
    as blockchain tokens (NFT-style).
*/
contract CredentialToken {

    // Reference to Registry contract
    Registry public registry;

    // Token collection name
    string public name = "Certproff Credential Token";

    // Token symbol
    string public symbol = "CCT";

    // Tracks token IDs
    uint256 private tokenCounter;

    /*
        Structure storing token information.
    */
    struct TokenData {

        uint256 tokenID;

        // Linked credential ID
        string credentialID;

        // Graduate wallet address
        address owner;
    }

    /*
        tokenID => TokenData
    */
    mapping(uint256 => TokenData) public tokens;

    // Event emitted when a credential token is minted
    event CredentialMinted(
        uint256 tokenID,
        string credentialID,
        address graduate
    );

    /*
        Constructor stores Registry
        contract address.
    */
    constructor(address registryAddress) {

        registry = Registry(registryAddress);
    }

    /*
        mintCredential()

        Creates a blockchain credential token
        for a graduate after certificate issuance.
    */
    function mintCredential(
        string memory _credentialID
    ) public {

        /*
            Retrieve credential details
            from Registry contract.
        */
        (
            ,
            ,
            ,
            ,
            CertificateStatus status,
            address graduateAddress
        ) = registry.getCredential(_credentialID);

        /*
            Ensure credential is active
            before minting token.
        */
        require(
            status == CertificateStatus.Active,
            "Credential not active"
        );

        // Generate next token ID
        tokenCounter++;

        /*
            Store token information.
        */
        tokens[tokenCounter] = TokenData({
            tokenID: tokenCounter,
            credentialID: _credentialID,
            owner: graduateAddress
        });

        /*
            Emit event for frontend apps
            and blockchain tracking.
        */
        emit CredentialMinted(
            tokenCounter,
            _credentialID,
            graduateAddress
        );
    }
}