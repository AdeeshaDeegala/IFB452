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

enum CertificateStatus {
    Active,
    Revoked,
    Corrected,
    Replaced
}

/// -----------------------------------------------------------------------
/// INSTITUTION CONTRACT
/// -----------------------------------------------------------------------

contract Institution {

    address public admin;

    mapping(address => bool) public approvedInstitutions;

    event InstitutionApproved(address institution);
    event InstitutionRemoved(address institution);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not system admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // approveInstitution
    function approveInstitution(address institution) public onlyAdmin {
        approvedInstitutions[institution] = true;

        emit InstitutionApproved(institution);
    }

    // removeInstitution
    function removeInstitution(address institution) public onlyAdmin {
        approvedInstitutions[institution] = false;

        emit InstitutionRemoved(institution);
    }

    function isApproved(address institution) public view returns (bool) {
        return approvedInstitutions[institution];
    }
}

/// -----------------------------------------------------------------------
/// REGISTRY CONTRACT
/// -----------------------------------------------------------------------

contract Registry {

    Institution public institutionContract;

    constructor(address institutionAddress) {
        institutionContract = Institution(institutionAddress);
    }

    struct Credential {

        string credentialID;
        string qualificationTitle;
        string issuingInstitution;
        uint256 issueDate;

        CertificateStatus status;

        address graduateAddress;

        bool exists;
    }

    mapping(string => Credential) private credentials;

    event CertificateIssued(
        string credentialID,
        string qualificationTitle,
        string issuingInstitution,
        address graduate
    );

    event StatusUpdated(
        string credentialID,
        CertificateStatus status
    );

    modifier onlyApprovedInstitution() {
        require(
            institutionContract.isApproved(msg.sender),
            "Institution not approved"
        );
        _;
    }

    // issueCertificate
    function issueCertificate(
        string memory _credentialID,
        string memory _qualificationTitle,
        string memory _issuingInstitution,
        address _graduateAddress
    ) public onlyApprovedInstitution {

        require(
            !credentials[_credentialID].exists,
            "Credential already exists"
        );

        credentials[_credentialID] = Credential({
            credentialID: _credentialID,
            qualificationTitle: _qualificationTitle,
            issuingInstitution: _issuingInstitution,
            issueDate: block.timestamp,
            status: CertificateStatus.Active,
            graduateAddress: _graduateAddress,
            exists: true
        });

        emit CertificateIssued(
            _credentialID,
            _qualificationTitle,
            _issuingInstitution,
            _graduateAddress
        );
    }

    // updateStatus
    function updateStatus(
        string memory _credentialID,
        CertificateStatus _status
    ) public onlyApprovedInstitution {

        require(
            credentials[_credentialID].exists,
            "Credential does not exist"
        );

        credentials[_credentialID].status = _status;

        emit StatusUpdated(_credentialID, _status);
    }

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
        require(
            credentials[_credentialID].exists,
            "Credential does not exist"
        );

        Credential memory c = credentials[_credentialID];

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

contract Verification {

    Registry public registry;

    constructor(address registryAddress) {
        registry = Registry(registryAddress);
    }

    struct VerificationResult {

        string credentialID;
        string qualificationTitle;
        string issuingInstitution;
        uint256 issueDate;
        CertificateStatus status;
        bool valid;
    }

    // verifyCredential
    function verifyCredential(
        string memory _credentialID
    )
        public
        view
        returns (VerificationResult memory)
    {

        (
            string memory credentialID,
            string memory qualificationTitle,
            string memory issuingInstitution,
            uint256 issueDate,
            CertificateStatus status,

        ) = registry.getCredential(_credentialID);

        bool isValid = (status == CertificateStatus.Active);

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

contract CredentialToken {

    Registry public registry;

    string public name = "Certproff Credential Token";
    string public symbol = "CCT";

    uint256 private tokenCounter;

    struct TokenData {
        uint256 tokenID;
        string credentialID;
        address owner;
    }

    mapping(uint256 => TokenData) public tokens;

    event CredentialMinted(
        uint256 tokenID,
        string credentialID,
        address graduate
    );

    constructor(address registryAddress) {
        registry = Registry(registryAddress);
    }

    // mintCredential
    function mintCredential(
        string memory _credentialID
    ) public {

        (
            ,
            ,
            ,
            ,
            CertificateStatus status,
            address graduateAddress
        ) = registry.getCredential(_credentialID);

        require(
            status == CertificateStatus.Active,
            "Credential not active"
        );

        tokenCounter++;

        tokens[tokenCounter] = TokenData({
            tokenID: tokenCounter,
            credentialID: _credentialID,
            owner: graduateAddress
        });

        emit CredentialMinted(
            tokenCounter,
            _credentialID,
            graduateAddress
        );
    }
}