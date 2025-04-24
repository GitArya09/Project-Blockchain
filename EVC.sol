// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract EVcharging {

    address private deployedOwner;

    constructor() {
        deployedOwner = msg.sender;
    }

    struct EVChargingStationOwner {
        string name;
        uint8 age;
        string gender;
        string contactNumber;
        string email;
        bool registered;
    }

    struct EVUser {
        string name;
        uint8 age;
        string gender;
        string contactNumber;
        string email;
        bool registered;
    }

    enum Availability { AVAILABLE, OCCUPIED }

    struct StationDetails {
        string name;
        string location;
        uint8 powerSupply;
        string chargingType;
    }

    struct EVChargingStation {
        uint64 uniqueStationId;
        StationDetails details;
        Availability availability;
        uint priceRate;
        uint slotTime;
        uint feeCollected;
        address payable owner;
        uint timeOperation;
        address payable currentUser;
        bool registered;
    }

    event LogRegisterUser(address indexed user, string status);
    event LogRegisterStation(uint stationId, address indexed user, string status);
    event LogStartCharging(uint fee, string status);
    event LogStopCharging(string transactionStatus, string feedback);
    event LogRating(uint stationId, uint8 rating);
    event LogBooking(address indexed user, uint stationId, uint time);

    mapping(address => EVChargingStationOwner) owners;
    mapping(address => EVUser) public users;
    mapping(uint => EVChargingStation) public stations;
    mapping(uint => uint[]) public stationRatings;
    mapping(address => mapping(uint => uint)) public bookingSchedule;

    modifier onlyStationOwner(uint stationId) {
        require(stations[stationId].owner == msg.sender, "Only station owner can update");
        _;
    }

    function registerUser(string memory name, uint8 age, string memory gender, string memory contactNumber, string memory email) public {
        require(!users[msg.sender].registered, "User already registered");
        users[msg.sender] = EVUser(name, age, gender, contactNumber, email, true);
        emit LogRegisterUser(msg.sender, "Registration successful");
    }

    function registerStation(uint64 stationId, string memory name, string memory location, uint8 powerSupply, string memory chargingType, uint priceRate) public {
        require(!stations[stationId].registered, "Station already registered");

        StationDetails memory details = StationDetails(name, location, powerSupply, chargingType);

        stations[stationId] = EVChargingStation(
            stationId,
            details,
            Availability.AVAILABLE,
            priceRate,
            0,
            0,
            payable(msg.sender),
            0,
            payable(address(0)),
            true
        );

        emit LogRegisterStation(stationId, msg.sender, "Station registration successful");
    }

    function updatePriceRate(uint stationId, uint newRate) public onlyStationOwner(stationId) {
        stations[stationId].priceRate = newRate;
    }

    function startCharging(uint stationId, uint currentTime, uint slotTime, uint operationTime) public payable {
        EVChargingStation storage station = stations[stationId];
        require(station.registered, "Station not registered");
        require(users[msg.sender].registered, "User not registered");

        if (station.availability == Availability.AVAILABLE || (station.slotTime + station.timeOperation < currentTime)) {
            station.availability = Availability.OCCUPIED;
            station.slotTime = slotTime;
            station.timeOperation = operationTime;
            station.currentUser = payable(msg.sender);
            station.feeCollected = msg.value;
            emit LogStartCharging(msg.value, "Charging started");
        } else {
            revert("Station currently occupied");
        }
    }

    function stopCharging(uint stationId, uint currentTime) public {
        EVChargingStation storage station = stations[stationId];
        require(station.registered, "Station not registered");
        require(station.currentUser == msg.sender, "Only current user can stop charging");

        uint fee = station.feeCollected;
        uint slot = station.slotTime;
        uint price = slot * station.priceRate;
        uint opTime = station.timeOperation;

        if (slot + opTime > currentTime) {
            station.owner.transfer(price);
            uint refund = fee > price ? fee - price : 0;
            if (refund > 0) {
                (bool success, ) = payable(msg.sender).call{value: refund}("");
                require(success, "Refund failed");
            }
        } else {
            station.owner.transfer(fee);
        }

        station.availability = Availability.AVAILABLE;
        station.currentUser = payable(address(0));
        station.feeCollected = 0;
        station.slotTime = 0;
        station.timeOperation = 0;

        emit LogStopCharging("Transaction successful", "Please rate the station");
    }

    function rateStation(uint stationId, uint8 rating) public {
        require(rating >= 1 && rating <= 5, "Invalid rating");
        stationRatings[stationId].push(rating);
        emit LogRating(stationId, rating);
    }

    function getAverageRating(uint stationId) public view returns (uint) {
        uint[] memory ratings = stationRatings[stationId];
        uint total;
        for (uint i = 0; i < ratings.length; i++) {
            total += ratings[i];
        }
        return ratings.length > 0 ? total / ratings.length : 0;
    }

    function bookSlot(uint stationId, uint time) public {
        require(users[msg.sender].registered, "User not registered");
        require(stations[stationId].registered, "Station not registered");
        bookingSchedule[msg.sender][stationId] = time;
        emit LogBooking(msg.sender, stationId, time);
    }

    function getPriceRate(uint stationId) public view returns (uint) {
        return stations[stationId].priceRate;
    }
}
