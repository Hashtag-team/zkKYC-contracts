// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title ZK-KYC Verification Interface
 * @notice Определяет стандарт для децентрализованной KYC-верификации с использованием zk-SNARKs
 * @dev Все функции должны быть реализованы в основном контракте
 */
interface IZkKYC {
    /// @notice Событие при успешной верификации KYC
    /// @param user Адрес верифицированного пользователя
    /// @param countryCode Код страны (2 буквы)
    event KYCVerified(address indexed user, bytes2 countryCode);

    /// @notice Событие при отзыве KYC
    /// @param user Адрес пользователя
    /// @param reason Причина отзыва (1 = подозрительная активность, 2 = истечение срока)
    event KYCRevoked(address indexed user, uint8 reason);

    /**
     * @notice Верификация пользователя через zk-пруф
     * @dev Только регулятор может вызывать
     * @param user Адрес пользователя
     * @param ageProof zk-пруф возраста (>=18)
     * @param countryProof zk-пруф гражданства
     * @param additionalData Дополнительные данные (пол, судимость)
     */
    function verifyKYC(
        address user,
        bytes calldata ageProof,
        bytes calldata countryProof,
        bytes calldata additionalData
    ) external;

    /**
     * @notice Отзыв KYC-статуса
     * @dev Только регулятор может вызывать
     * @param user Адрес пользователя
     * @param reason Код причины (1-255)
     */
    function revokeKYC(address user, uint8 reason) external;

    /**
     * @notice Проверка KYC-статуса
     * @param user Адрес пользователя
     * @return isValid Актуален ли KYC
     * @return countryCode Код страны
     */
    function checkKYC(address user) external view returns (bool isValid, bytes2 countryCode);
}