// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title DID Identity System Interface
 * @notice Определяет стандарт для системы Self-Sovereign Identity с DID
 * @dev Все функции должны быть реализованы в основном контракте
 */
interface IDIDIdentitySystem {
    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------
    
    /// @notice Событие при создании нового DID
    /// @param did Децентрализованный идентификатор
    /// @param owner Владелец DID
    event DIDCreated(string indexed did, address indexed owner);
    
    /// @notice Событие при выдаче верифицированного заявления
    /// @param did DID пользователя
    /// @param claimId ID заявления
    /// @param claimType Тип заявления (age, citizenship и т.д.)
    event ClaimIssued(string indexed did, uint256 indexed claimId, string claimType);
    
    /// @notice Событие при отзыве верифицированного заявления
    /// @param did DID пользователя
    /// @param claimId ID заявления
    event ClaimRevoked(string indexed did, uint256 indexed claimId);
    
    /// @notice Событие при создании отчета о подозрительной активности
    /// @param reportId ID отчета
    /// @param didSubject DID подозреваемого пользователя
    /// @param business Адрес бизнеса, создавшего отчет
    event ReportFiled(uint256 indexed reportId, string didSubject, address indexed business);
    
    /// @notice Событие при разрешении отчета регулятором
    /// @param reportId ID отчета
    event ReportResolved(uint256 indexed reportId);
    
    /// @notice Событие при авторизации нового бизнеса
    /// @param business Адрес бизнеса
    event BusinessAuthorized(address indexed business);
    
    /// @notice Событие при авторизации нового регулятора
    /// @param regulator Адрес регулятора
    event RegulatorAuthorized(address indexed regulator);
    
    /// @notice Событие при авторизации нового верификатора
    /// @param verifier Адрес верификатора
    event VerifierAuthorized(address indexed verifier);

    // ------------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------------
    
    /// @dev Ошибка при попытке создать DID для адреса, у которого уже есть DID
    error AddressAlreadyHasDID();
    
    /// @dev Ошибка при попытке создать уже существующий DID
    error DIDAlreadyExists();
    
    /// @dev Ошибка при работе с несуществующим DID
    error DIDNotFound();
    
    /// @dev Ошибка при попытке отозвать несуществующее или невалидное заявление
    error InvalidClaim();
    
    /// @dev Ошибка при отсутствии авторизации для выполнения действия
    error NotAuthorized();
    
    /// @dev Ошибка при работе с несуществующим отчетом
    error ReportNotFound();

    // ------------------------------------------------------------------------
    // DID Management Functions
    // ------------------------------------------------------------------------
    
    /**
     * @notice Создание нового DID для пользователя
     * @param didString Строка DID (соответствует стандарту W3C DID)
     * @return Успешность операции
     */
    function createDID(string memory didString) external returns (bool);
    
    /**
     * @notice Получение DID по адресу пользователя
     * @param addr Адрес пользователя
     * @return DID пользователя
     */
    function getDIDByAddress(address addr) external view returns (string memory);

    // ------------------------------------------------------------------------
    // Verifiable Claims Functions
    // ------------------------------------------------------------------------
    
    /**
     * @notice Добавление верифицированного заявления
     * @param did DID пользователя
     * @param claimType Тип заявления
     * @param claimValue Зашифрованное значение
     * @param proofValue Доказательство для регулятора
     * @param expirationDate Срок действия
     * @return ID созданного заявления
     */
    function addVerifiableClaim(
        string memory did,
        string memory claimType,
        string memory claimValue,
        bytes memory proofValue,
        uint256 expirationDate
    ) external returns (uint256);
    
    /**
     * @notice Отзыв верифицированного заявления
     * @param did DID пользователя
     * @param claimId ID заявления
     */
    function revokeVerifiableClaim(string memory did, uint256 claimId) external;
    
    /**
     * @notice Проверка валидности заявления
     * @param did DID пользователя
     * @param claimType Тип заявления
     * @return Наличие валидного заявления
     */
    function hasValidClaim(string memory did, string memory claimType) external view returns (bool);
    
    /**
     * @notice Верификация ZK-доказательства
     * @param did DID пользователя
     * @param claimType Тип заявления
     * @param zkProof ZK-доказательство
     * @return Результат верификации
     */
    function verifyZKP(string memory did, string memory claimType, bytes memory zkProof) external returns (bool);

    // ------------------------------------------------------------------------
    // Suspicious Activity Functions
    // ------------------------------------------------------------------------
    
    /**
     * @notice Создание отчета о подозрительной активности
     * @param didSubject DID подозреваемого
     * @param reportType Тип отчета
     * @param encryptedDetails Зашифрованные детали
     * @return ID созданного отчета
     */
    function fileReport(
        string memory didSubject,
        string memory reportType,
        string memory encryptedDetails
    ) external returns (uint256);
    
    /**
     * @notice Разрешение отчета регулятором
     * @param reportId ID отчета
     * @param isResolved Статус разрешения
     */
    function resolveReport(uint256 reportId, bool isResolved) external;
    
    /**
     * @notice Получение деталей отчета (только для регулятора)
     * @param reportId ID отчета
     */
    function getReportDetails(uint256 reportId) external view returns (
        string memory didSubject,
        address reportingBusiness,
        string memory reportType,
        string memory encryptedDetails,
        uint256 timestamp,
        bool isResolved
    );

    // ------------------------------------------------------------------------
    // Role Management Functions
    // ------------------------------------------------------------------------
    
    /**
     * @notice Добавление регулятора
     * @param regulator Адрес регулятора
     */
    function addRegulator(address regulator) external;
    
    /**
     * @notice Добавление бизнеса
     * @param business Адрес бизнеса
     */
    function addBusiness(address business) external;
    
    /**
     * @notice Добавление верификатора
     * @param verifier Адрес верификатора
     */
    function addVerifier(address verifier) external;
}