// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title DIDIdentitySystem
 * @dev Реализация системы Self-Sovereign Identity с использованием Decentralized ID (DID)
 * Поддерживает требования по конфиденциальности персональных данных и взаимодействию между
 * пользователями, бизнесами и регуляторами.
 */
contract DIDIdentitySystem is ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    using Strings for uint256;

    // Роли для контроля доступа
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");
    bytes32 public constant BUSINESS_ROLE = keccak256("BUSINESS_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    // Счетчик для ID верифицируемых заявлений
    Counters.Counter private _claimIds;
    
    // Счетчик для NFT идентификаторов
    Counters.Counter private _tokenIds;
    
    // Хранение DID документов и верифицируемых заявлений
    struct DIDDocument {
        string did; // Decentralized Identifier
        bool isActive;
        mapping(uint256 => VerifiableClaim) claims; // Связанные верифицируемые заявления
        uint256[] claimIds; // Список ID заявлений
    }
    
    struct VerifiableClaim {
        uint256 id;
        string claimType; // Тип заявления (например, "age", "citizenship", "not_terrorist")
        string claimValue; // Значение заявления, хранится в зашифрованном виде
        bool isValid;
        address verifier; // Кто проверил заявление
        bytes proofValue; // Зашифрованное доказательство, доступное только регулятору
        uint256 expirationDate; // Срок действия верифицируемого заявления
    }
    
    // Структура для отчетов о подозрительной активности
    struct SuspiciousActivityReport {
        uint256 id;
        string didSubject; // DID пользователя, о котором составлен отчет
        address reportingBusiness; // Бизнес, сообщающий о подозрении
        string reportType; // Тип отчета
        string encryptedDetails; // Зашифрованные детали, которые может прочитать только регулятор
        uint256 timestamp; // Время создания отчета
        bool isResolved; // Статус расследования
    }
    
    // Учет DID документов
    mapping(string => DIDDocument) private _didDocuments;
    mapping(address => string) private _addressToDID;
    
    // Учет отчетов о подозрительной активности
    mapping(uint256 => SuspiciousActivityReport) private _reports;
    Counters.Counter private _reportIds;
    
    // Временное хранение заявлений для поддержки ZKP (Zero-Knowledge Proofs)
    mapping(bytes32 => bool) private _zkVerifications;
    
    // События
    event DIDCreated(string did, address owner);
    event ClaimIssued(string did, uint256 claimId, string claimType);
    event ClaimRevoked(string did, uint256 claimId);
    event ReportFiled(uint256 reportId, string didSubject, address business);
    event ReportResolved(uint256 reportId);
    event BusinessAuthorized(address business);
    event RegulatorAuthorized(address regulator);
    event VerifierAuthorized(address verifier);
    
    constructor() ERC721("Decentralized Identity", "DID") payable {
        // по умолчанию админ тот кто задеплоил контракт
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    // Функции для управления DID и верифицируемыми заявлениями
    
    /**
     * @dev Создание нового DID для пользователя
     * @param didString Строка DID, соответствующая стандарту W3C DID
     * @return Успешно ли создан DID
     */
    function createDID(string memory didString) public returns (bool) {
        require(bytes(_addressToDID[msg.sender]).length == 0, "Address already has DID");
        require(bytes(_didDocuments[didString].did).length == 0, "DID already exists");
        
        _addressToDID[msg.sender] = didString;
        _didDocuments[didString].did = didString;
        _didDocuments[didString].isActive = true;
        
        // Создаем NFT-представление DID
        uint256 newTokenId = _tokenIds.current();
        _tokenIds.increment();
        _safeMint(msg.sender, newTokenId);
        
        // Генерируем метаданные NFT с DID
        string memory tokenURI = _generateTokenURI(didString, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        
        emit DIDCreated(didString, msg.sender);
        return true;
    }
    
    /**
     * @dev Добавление верифицированного заявления к DID
     * @param did DID пользователя
     * @param claimType Тип заявления
     * @param claimValue Зашифрованное значение заявления
     * @param proofValue Зашифрованное доказательство, доступное регулятору
     * @param expirationDate Срок действия заявления
     * @return ID созданного заявления
     */
    function addVerifiableClaim(
        string memory did,
        string memory claimType,
        string memory claimValue,
        bytes memory proofValue,
        uint256 expirationDate
    ) public onlyRole(VERIFIER_ROLE) returns (uint256) {
        require(bytes(_didDocuments[did].did).length > 0, "DID does not exist");
        require(_didDocuments[did].isActive, "DID is not active");
        
        uint256 claimId = _claimIds.current();
        _claimIds.increment();
        
        VerifiableClaim storage newClaim = _didDocuments[did].claims[claimId];
        newClaim.id = claimId;
        newClaim.claimType = claimType;
        newClaim.claimValue = claimValue;
        newClaim.isValid = true;
        newClaim.verifier = msg.sender;
        newClaim.proofValue = proofValue;
        newClaim.expirationDate = expirationDate;
        
        _didDocuments[did].claimIds.push(claimId);
        
        emit ClaimIssued(did, claimId, claimType);
        return claimId;
    }
    
    /**
     * @dev Отзыв верифицированного заявления
     * @param did DID пользователя
     * @param claimId ID заявления для отзыва
     */
    function revokeVerifiableClaim(string memory did, uint256 claimId) public {
        require(bytes(_didDocuments[did].did).length > 0, "DID does not exist");
        require(_didDocuments[did].claims[claimId].isValid, "Claim not valid or doesn't exist");
        require(
            _didDocuments[did].claims[claimId].verifier == msg.sender || 
            hasRole(REGULATOR_ROLE, msg.sender), 
            "Not authorized to revoke"
        );
        
        _didDocuments[did].claims[claimId].isValid = false;
        
        emit ClaimRevoked(did, claimId);
    }
    
    /**
     * @dev Проверка наличия действительного заявления определенного типа
     * @param did DID пользователя
     * @param claimType Тип заявления для проверки
     * @return Наличие действительного заявления указанного типа
     */
    function hasValidClaim(string memory did, string memory claimType) public view returns (bool) {
        if(bytes(_didDocuments[did].did).length == 0) return false;
        if(!_didDocuments[did].isActive) return false;
        
        uint256[] memory claimIds = _didDocuments[did].claimIds;
        for(uint i = 0; i < claimIds.length; i++) {
            uint256 claimId = claimIds[i];
            VerifiableClaim storage claim = _didDocuments[did].claims[claimId];
            
            if(claim.isValid && 
               keccak256(bytes(claim.claimType)) == keccak256(bytes(claimType)) &&
               claim.expirationDate > block.timestamp) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @dev Поддержка Zero-Knowledge Proof для проверки заявлений без раскрытия данных
     * @param did DID пользователя
     * @param claimType Тип заявления
     * @param zkProof Доказательство, подтверждающее соответствие требованию
     * @return Результат проверки
     */
    function verifyZKP(string memory did, string memory claimType, bytes memory zkProof) public onlyRole(BUSINESS_ROLE) returns (bool) {
        // Здесь должен быть код для проверки ZKP
        // В реальной имплементации это было бы сложнее и использовало бы внешние библиотеки для ZKP

        // Для упрощения, мы здесь просто проверяем, есть ли у пользователя соответствующее заявление
        bytes32 proofHash = keccak256(abi.encodePacked(did, claimType, zkProof));
        _zkVerifications[proofHash] = hasValidClaim(did, claimType);
        
        return _zkVerifications[proofHash];
    }
    
    // Функции для управления подозрительной активностью
    
    /**
     * @dev Бизнес создает отчет о подозрительной активности
     * @param didSubject DID подозреваемого пользователя
     * @param reportType Тип отчета
     * @param encryptedDetails Зашифрованные детали, которые может прочитать только регулятор
     * @return ID созданного отчета
     */
    function fileReport(
        string memory didSubject,
        string memory reportType,
        string memory encryptedDetails
    ) public onlyRole(BUSINESS_ROLE) returns (uint256) {
        require(bytes(_didDocuments[didSubject].did).length > 0, "DID does not exist");
        
        uint256 reportId = _reportIds.current();
        _reportIds.increment();
        
        SuspiciousActivityReport storage newReport = _reports[reportId];
        newReport.id = reportId;
        newReport.didSubject = didSubject;
        newReport.reportingBusiness = msg.sender;
        newReport.reportType = reportType;
        newReport.encryptedDetails = encryptedDetails;
        newReport.timestamp = block.timestamp;
        newReport.isResolved = false;
        
        emit ReportFiled(reportId, didSubject, msg.sender);
        return reportId;
    }
    
    /**
     * @dev Регулятор обрабатывает отчет о подозрительной активности
     * @param reportId ID отчета
     * @param isResolved Статус разрешения
     */
    function resolveReport(uint256 reportId, bool isResolved) public onlyRole(REGULATOR_ROLE) {
        require(_reports[reportId].id == reportId, "Report does not exist");
        
        _reports[reportId].isResolved = isResolved;
        
        emit ReportResolved(reportId);
    }
    
    /**
     * @dev Регулятор получает доступ к зашифрованным данным пользователя
     * @param did DID пользователя
     * @param claimId ID заявления
     * @return Зашифрованное доказательство
     */
    function getProofForRegulator(string memory did, uint256 claimId) public view onlyRole(REGULATOR_ROLE) returns (bytes memory) {
        require(bytes(_didDocuments[did].did).length > 0, "DID does not exist");
        require(_didDocuments[did].claims[claimId].id == claimId, "Claim does not exist");
        
        return _didDocuments[did].claims[claimId].proofValue;
    }
    
    /**
     * @dev Получение деталей отчета (только для регулятора)
     * @param reportId ID отчета
     */
    function getReportDetails(uint256 reportId) public view onlyRole(REGULATOR_ROLE) returns (
        string memory didSubject,
        address reportingBusiness,
        string memory reportType,
        string memory encryptedDetails,
        uint256 timestamp,
        bool isResolved
    ) {
        SuspiciousActivityReport storage report = _reports[reportId];
        require(report.id == reportId, "Report does not exist");
        
        return (
            report.didSubject,
            report.reportingBusiness,
            report.reportType,
            report.encryptedDetails,
            report.timestamp,
            report.isResolved
        );
    }
    
    // Функции для управления ролями
    
    /**
     * @dev Добавление нового регулятора
     * @param regulator Адрес регулятора
     */
    function addRegulator(address regulator) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(REGULATOR_ROLE, regulator);
        emit RegulatorAuthorized(regulator);
    }
    
    /**
     * @dev Добавление нового бизнеса
     * @param business Адрес бизнеса
     */
    function addBusiness(address business) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BUSINESS_ROLE, business);
        emit BusinessAuthorized(business);
    }
    
    /**
     * @dev Добавление нового верификатора (выдающего заявления)
     * @param verifier Адрес верификатора
     */
    function addVerifier(address verifier) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(VERIFIER_ROLE, verifier);
        emit VerifierAuthorized(verifier);
    }
    
    // Вспомогательные функции
    
    /**
     * @dev Генерирует URI токена
     * @param did DID пользователя
     * @param tokenId ID токена
     */
    function _generateTokenURI(string memory did, uint256 tokenId) private pure returns (string memory) {
        bytes memory metadata = abi.encodePacked(
            '{',
            '"name": "Decentralized Identity #', tokenId.toString(), '",',
            '"description": "Self-Sovereign Identity DID",',
            '"did": "', did, '"',
            '}'
        );
        
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(metadata)
            )
        );
    }
    
    /**
     * @dev Возвращает DID, связанный с адресом
     * @param addr Адрес пользователя
     * @return DID пользователя
     */
    function getDIDByAddress(address addr) public view returns (string memory) {
        return _addressToDID[addr];
    }
    
    // Реализация интерфейсов OpenZeppelin
    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}