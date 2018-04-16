pragma solidity 0.4.21;

contract EtherGalaxy {
    
    //Structs//
    
    struct Star {  //Primary object, produces energy, parent to planets and stations
        address owner;  //Owner address
        uint8 sectorId;  //Sector located in, planets/station children inherit this
        uint8 level;  //Level, upgradeable, determines max # of planets/stars, and energy production w/energyOutput
        uint8 energyOutput;  //Determines energy production w/level
        uint32 starId;  //Reference ID # in mapping starCollection, starts at 1 and increments
        uint32[] planets;  //Array of parent planet IDs
        uint32[] stations;  //Array of parent station IDs
        uint256 defense;  //Defense value, number of drones stationed here
        uint256 lastProduce;  //Block number of last time produced energy
        //uint256 createTime;  //Block number of creation
    }
    
    struct Planet {  //Secondary object, specializes in producing a certain material from energy, population feature later
        address owner;  //Owner address
        uint8 sectorId;  //Sector located in, inherited from parent star
        uint8 produceId;  //Material produced by this planet, must be set by owner after creation
        uint8 produceOutput;  //Determines material production w/level
        uint8 level;  //Level, upgradeable, determines level of material that can be produced, and material production w/produceOutput
        uint32 planetId;  //Reference ID # in mapping planetCollection, starts at 1 and increments
        uint32 parentStarId;  //Reference ID # of parent star
        uint256 defense;  //Defense value, number of drones stationed here
        //uint256 population;  //Current population, not implemented
        //uint256 maxPopulation;  //Max population, not implemented
        uint256 lastProduce;  //Block number of last time produced material
        //uint256 createTime;  //Block number of creation
    }
    
    struct Station {  //Secondary object, produces drones and ships from materials and energy, allows maintenance of ships
        address owner;  //Owner address
        uint8 sectorId;  //Sector located in, inherited from parent star
        uint8 level;  //Level, upgradeable, determines level of material that can be used, and drone output
        uint32 stationId;  //Reference ID # in mapping stationCollection, starts at 1 and increments
        uint32 parentStarId;  //Reference ID # of parent star
        uint256 defense;  //Defense value, number of drones stationed here
        uint256 lastProduce;  //Block number of last time produced drones
        //uint256 createTime;  //Block number of creation
    }
    
    struct Ship {  //Tertiary object, primary gameplay element, allows exploring the map, fighting, and other features?
        address owner;  //Owner address
        bool docked;  //Whether the ship is docked at a station/planet
        uint8 sectorId;  //Sector located in, docked or otherwise
        uint8 level;  //Level, upgradeable, determines stats
        uint16 hull;  //Current hull condition, ship is forced to dock if 0
        uint16 maxHull;  //Max hull condition, can be upgraded
        uint16 shortDamage; //Short range damage, can be upgraded
        uint16 longDamage;  //Long range damage, can be upgraded
        uint16 speed;  //Ship's speed, both in and out of combat, can be upgraded
        uint16 shield;  //Ship's shield, takes damage before hull. Can be purchased and has no limit
        uint32 shipId;  //Reference ID # in mapping shipCollection, starts at 1 and increments
        uint256 energy;  //Amount of energy stored in ship, used for moving and other actions
        uint256 exploreTime;  //Block number of last time explored
        //uint256 createTime;  //Block number of creation
    }
    
    struct Material {  //Produced by planets from energy, used in producing drones and ships, and other features?
        //uint8 materialId;  //Reference ID # in mapping materialCollection. Not used so removed.
        uint8 level;  //Level of material, planet/station must be at least this level to use, if level is higher, it uses the material better
        mapping(address => uint256) balances;  //Mapping of user balances of this material
    }
    
    struct Sector {  //Map sector of galaxy. 15x15 grid, 1 => 225
        address owner;  //Owner address. Not sure how to do this one yet
        uint8 sectorId;  //Reference ID # in fixed-array galaxyMap
        uint8 border;  //If sector is on border of map. 0: no border, 1: top border, 2: right border, 3: left border, 4: bottom border
        uint8 level;  //Level, upgradeable, determines something
        uint8 wormholeId;  //Connects this sector to the sector at this ID, ID randomly set at discovery. Reward for discovery?
        uint32[] stars;  //Stars in sector
        uint256 defense;  //Defense value, number of drones stationed here
        //uint256 credits;  //Amount of credits in sector account
        //uint256 tax;  //Tax, not implemented
    }
    
    struct Blackhole {  //Gameplay object, essentially a jackpot. Maximum of 250, randomly discovered when exploring
        //Owner sets jackpot round (maxPlayers, endTime, and materialId) and can end/distribute winnings any time after endTime.
        address owner;  //Owner address. Only allowed one blackhole per address. Owner receives 10% of jackpot winnings
        address[] players;  //Array of player addresses for the round
        bool active;  //Whether the pot is active
        uint8 blackholeId;  //Reference ID # in mapping blackholeCollection, starts at 1 and increments, 250 max
        uint8 materialId;  //Material used for the round. Players send this material to the blackhole
        uint8 maxPlayers;  //Maximum number of players for the round. Round can still be ended if currentPlayers < maxPlayers
        uint8 currentPlayers;  //Current number of players
        uint256 store;  //Material storage for the round
        uint256 startTime;  //Block number of round start
        uint256 endTime;  //Block number of round end
        //uint256 discoverTime;  //Block number of discovery
        mapping(address => uint256) amount;  //Mapping of player contributions for the round
    }
    
    //////
    
    //Events//
    
    event NewStard(uint32 _starId, uint8 _sectorId);
    event NewPlanetd(uint32 _planetId, uint32 _parentId);
    event NewStationd(uint32 _stationId, uint32 _parentId);
    event NewShipd(uint32 _shipId, uint32 _parentId);
    event Producedd(uint32 _objectId, uint8 _materialId, uint256 _amt);
    event ProducedDronesd(uint32 _stationId, uint256 _amt);
    event AssetAttacked(uint32 _objectId, uint8 _type, uint256 _amt);
    event AssetDefended(uint32 _objectId, uint8 _type, uint256 _amt);
    event AssetLeveled(uint32 _objectId, uint8 _type, uint8 _level);
    event BlackholeStarted(uint8 _id, uint8 _materialId, uint8 _maxPlayers);
    event BlackholePlayed(uint8 _id, uint256 _amt);
    event BlackholeEnded(uint8 _id, address _address);
    event ShipDocked(uint32 _shipId, bool _planetOrStation, uint32 _id);
    event ShipRefueled(uint32 _shipId);
    event ShipRepaired(uint32 _shipId);
    event ShipExplored(uint32 _shipId, uint8 _result, uint8 _sectorId);
    event ShipMoved(uint32 _shipId, uint8 _dir, uint8 _sectorId);
    
    //////
    
    //Mappings//
    
    Sector[226] public galaxyMap;  //Array of sectors, 225 total, index 0 not used
    mapping(uint8 => bytes16) public sectorNames; 
    
    //mapping(address => uint256) public creditBalances;  //Address balances of credits (not really implemented)
    //mapping(address => uint256) public XPBalances;  //Address balances of XP (not really implemented)
    mapping(address => uint256) public energyBalances;  //Address balances of energy
    mapping(address => uint256) public droneBalances;  //Address balances of drones
    
    mapping(uint32 => Star) public starCollection;  //Collection of star objects
    mapping(address => uint32[]) public playerStars;  //Shows stars owned by an address
    
    mapping(uint32 => Planet) public planetCollection;  //Collection of planet objects
    mapping(address => uint32[]) public playerPlanets;  //Shows planets owned by an address
    
    mapping(uint32 => Station) public stationCollection;  //Collection of station objects
    mapping(address => uint32[]) public playerStations;  //Shows stations owned by an address
    
    mapping(uint32 => Ship) public shipCollection;  //Collection of ships
    mapping(address => uint32[]) public playerShips;  //Shows ships owned by an address
    //mapping(uint8 => uint32[]) public sectorShips;  //Shows ships in sector
    
    mapping(uint8 => Material) public materialCollection;  //Collection of materials
    
    mapping(uint8 => Blackhole) public blackholeCollection;  //Collection of blackholes (max 250)
    mapping(address => bool) public ownsBlackhole;  //Shows if address owns blackhole (one person address)
    
    mapping(address => bool) public playedBefore;  //Checks if first time address has played
    mapping(address => bool) public ownsSector;  //Shows if address owns sector (one person address)
    
    //////
    
    //Variables//
    
    address owner;
    uint32 public totalStars = 0;  //Total number of stars, used for setting new star ID's
    uint32 public totalPlanets = 0;  //Total number of planets, used for setting new planet ID's
    uint32 public totalStations = 0;  //Total number of stations, used for setting new station ID's
    uint32 public totalShips = 0;  //Total number of ships, used for setting new ship ID's
    uint8 public totalMaterials = 10;  //Total number of materials, used for setting new material ID's
    uint8 public totalBlackholes = 0;  //Total number of blackholes, used for setting new blackhole ID's
    uint256 produceCooldown = 50;  //Cooldown in blocks for producing energy/materials
    uint256 exploreCooldown = 25;  //Cooldown in blocks for ship exploring
    uint256 starsPerSectorLevel = 10;
    uint nonce;  //Nonce used in RNG
    
    bool setup;  //Checks if game setup. NEED BEFORE GAME STARTS
    
    
    //////
    
    //Constructor//
    
    function EtherGalaxy() public {  //Constructor function, just sets contract owner to msg.sender 
        owner = msg.sender;
    }
    
    function compute() public {  //Sets up game. NEED BEFORE GAME STARTS
        require(setup == false);
        require(msg.sender == owner);
        for (uint8 i = 1; i < 226; i++) {
            Sector storage sector = galaxyMap[i];
            sector.sectorId = i;
            sector.level = 1;
            if (i < 16) {
                sector.border = 1;
            } else if (i % 15 == 0) {
                sector.border = 2;
            } else if ((i - 1) % 15 == 0) {
                sector.border = 3;
            } else if (i > 210) {
                sector.border = 4;
            }
            if (i < 11) {
                Material storage material = materialCollection[i];  //Hydrogen, Oxygen, Carbon, Iron, Silicon, Nitrogen, Copper, Aluminum, Neon, Uranium,
                material.level = i;
            }
        }
        setup = true;
    }
    
    //////
    
    //Asset Adding Functions//
    
    function newStar(uint8 _sectorId) public {  //Creates new star
        require(_sectorId > 0);
        require(_sectorId < 226);
        require(energyBalances[msg.sender] >= 200);
        Sector storage sector = galaxyMap[_sectorId];
        require(sector.stars.length < starsPerSectorLevel * sector.level);
        energyBalances[msg.sender] -= 200;
        totalStars++;
        Star storage star = starCollection[totalStars];
        star.owner = msg.sender;
        star.level = 1;
        star.sectorId = _sectorId;
        star.energyOutput = uint8(10 + _random(20));
        star.starId = totalStars;
        //star.createTime = block.number;
        playerStars[msg.sender].push(totalStars);
        sector.stars.push(totalStars);
        emit NewStard(totalStars, _sectorId);
    }
    
    function newPlanet(uint32 _parent) public {  //Creates new planet
        require(energyBalances[msg.sender] >= 250);
        Star storage star = starCollection[_parent];
        require(star.owner == msg.sender);
        require(star.planets.length < 2 * star.level);
        energyBalances[msg.sender] -= 250;
        totalPlanets++;
        Planet storage planet = planetCollection[totalPlanets];
        planet.owner = msg.sender;
        planet.level = 1;
        planet.produceId = 1;
        planet.sectorId = star.sectorId;
        planet.planetId = totalPlanets;
        //planet.maxPopulation = 100;
        //planet.createTime = block.number;
        planet.parentStarId = _parent;
        star.planets.push(totalPlanets);
        playerPlanets[msg.sender].push(totalPlanets);
        emit NewPlanetd(totalPlanets, _parent);
    }
    
    function newStation(uint32 _parent) public {  //Creates new station
        require(energyBalances[msg.sender] >= 250);
        Star storage star = starCollection[_parent];
        require(star.owner == msg.sender);
        require(star.stations.length < star.level);
        energyBalances[msg.sender] -= 250;
        totalStations++;
        Station storage station = stationCollection[totalStations];
        station.owner = msg.sender;
        station.level = 1;
        station.sectorId = star.sectorId;
        station.stationId = totalStations;
        //station.createTime = block.number;
        station.parentStarId = _parent;
        star.stations.push(totalStations);
        playerStations[msg.sender].push(totalStations);
        emit NewStationd(totalStations, _parent);
    }
    
    function newShip(uint32 _stationId, uint8 _m1, uint8 _m2, uint8 _m3, uint8 _m4) public {  //Creates new ship
        Station storage station = stationCollection[_stationId];
        Material storage m1 = materialCollection[_m1];  //Material for hull level. Level = material level
        Material storage m2 = materialCollection[_m2];  //Material for short damage level. Level = material level 
        Material storage m3 = materialCollection[_m3];  //Material for long damage level. Level = material level
        Material storage m4 = materialCollection[_m4];  //Material for speed level. Level = material level
        require(station.owner == msg.sender);
        require(m1.balances[msg.sender] >= 10);  //10 of each material for ship
        m1.balances[msg.sender] -= 10;
        require(m2.balances[msg.sender] >= 10);
        m2.balances[msg.sender] -= 10;
        require(m3.balances[msg.sender] >= 10);
        m3.balances[msg.sender] -= 10;
        require(m4.balances[msg.sender] >= 10);
        m4.balances[msg.sender] -= 10;
        totalShips++;
        Ship storage ship = shipCollection[totalShips];
        ship.owner = msg.sender;
        ship.level = 1;
        ship.energy = 10;
        ship.docked = true;
        ship.shipId = totalShips;
        ship.sectorId = station.sectorId;
        ship.maxHull = m1.level * 10;
        ship.hull = m1.level * 10;
        ship.shortDamage = m2.level;
        ship.longDamage = m3.level;
        ship.speed = m4.level;
        //ship.createTime = block.number;
        playerShips[msg.sender].push(totalShips);
        emit NewShipd(totalShips, _stationId);
    }
    
    function nameSector(uint8 _sectorId, bytes16 _name) public payable {
        Sector memory sector = galaxyMap[_sectorId];
        require(msg.sender == sector.owner);
        require(msg.value == 1 finney);
        sectorNames[_sectorId] = _name;
    }
    
    //////
    
    //Asset Management Functions//
    
    function assetProduce(bool _starOrPlanet, uint32 _id) public {  //Energy/material production function
        if (_starOrPlanet == true) {  //Checks if star or planet. True == star, false == planet
            Star storage star = starCollection[_id];
            require(msg.sender == star.owner);
            require(block.number - star.lastProduce > produceCooldown);
            star.lastProduce = block.number;
            energyBalances[msg.sender] += (star.level * star.energyOutput);
            emit Producedd(_id, 0, star.level * star.energyOutput);
        } else {
            Planet storage planet = planetCollection[_id];
            require(msg.sender == planet.owner);
            require(block.number - planet.lastProduce > produceCooldown);
            Material storage material = materialCollection[planet.produceId];
            require(energyBalances[planet.owner] >= 10 * material.level);
            energyBalances[planet.owner] -= 10 * material.level;
            planet.lastProduce = block.number;
            material.balances[planet.owner] += (planet.level * planet.produceOutput);
            emit Producedd(_id, planet.produceId, planet.level * planet.produceOutput);
        }
    }
    
    function assetSetProduction(uint32 _planetId, uint8 _materialId) public {  //Sets material that a planet will produce. Probably will require an amount of that material
        Material memory material = materialCollection[_materialId];
        Planet storage planet = planetCollection[_planetId];
        require(msg.sender == planet.owner);
        require(_materialId > 0);
        require(_materialId <= totalMaterials);
        require(planet.level >= material.level);
        require(energyBalances[planet.owner] >= 10);
        energyBalances[planet.owner] -= 10;
        planet.produceId = _materialId;
    }
    
    function assetProduceDrones(uint32 _stationId, uint256 _baseAmt, uint8 _materialId) public {  //Station produces drones. Amount created determined by level of material used
        Station memory station = stationCollection[_stationId];
        Material storage material = materialCollection[_materialId];
        require(msg.sender == station.owner);
        require(block.number - station.lastProduce > produceCooldown);
        require(station.level >= material.level);
        require(material.balances[station.owner] >= _baseAmt);
        station.lastProduce = block.number;
        material.balances[station.owner] -= _baseAmt;
        droneBalances[station.owner] += _baseAmt * material.level;
        emit ProducedDronesd(_stationId, _baseAmt * material.level);
    }
    
    function assetLevelUp(uint8 _type, uint32 _id) public {  //Level up star/planet/station. Not too sure about this one
        if (_type == 0) {
            Star storage star = starCollection[_id];
            require(msg.sender == star.owner);
            require(energyBalances[star.owner] >= 250 * star.level);
            energyBalances[star.owner] -= 250 * star.level;
            star.level++;
            emit AssetLeveled(_id, _type, star.level);
        } else if (_type == 1) {
            Planet storage planet = planetCollection[_id];
            require(msg.sender == planet.owner);
            require(energyBalances[planet.owner] >= 500 * planet.level);
            energyBalances[planet.owner] -= 500 * planet.level;
            planet.level++;
            emit AssetLeveled(_id, _type, planet.level);
        } else if (_type == 2) {
            Station storage station = stationCollection[_id];
            require(msg.sender == station.owner);
            require(energyBalances[msg.sender] >= 750 * station.level);
            energyBalances[station.owner] -= 750 * station.level;
            station.level++; 
            emit AssetLeveled(_id, _type, station.level);
        } else if (_type == 3) {
            Sector storage sector = galaxyMap[_id];
            require(msg.sender == sector.owner);
            require(energyBalances[sector.owner] >= 2500 * sector.level);
            energyBalances[sector.owner] -= 2500 * sector.level;
            sector.level++;
            emit AssetLeveled(_id, _type, sector.level);
        } else { revert();}
        
    }
    
    function assetAttack(uint8 _type, uint32 _id, uint256 _amt) public {  //Attack another player's asset. If you have more drones, you win. Maybe change?
        require(droneBalances[msg.sender] >= _amt);
        droneBalances[msg.sender] -= _amt;
        if (_type == 0) {
            Star storage star = starCollection[_id];
            require(msg.sender != star.owner);
            if (star.defense <= _amt) {
                star.defense = 0;
                _removeMapping(0, star.owner, star.starId);
                star.owner = msg.sender;
                playerStars[msg.sender].push(star.starId);
            } else {
                star.defense -= _amt;
            }
        } else if (_type == 1) {
            Planet storage planet = planetCollection[_id];
            require(msg.sender != planet.owner);
            if (planet.defense <= _amt) {
                planet.defense = 0;
                _removeMapping(1, planet.owner, planet.planetId);
                planet.owner = msg.sender;
                playerPlanets[msg.sender].push(planet.planetId);
            } else {
                planet.defense -= _amt;
            }
        } else if (_type == 2) {
            Station storage station = stationCollection[_id];
            require(msg.sender != station.owner);
            if (station.defense <= _amt) {
                station.defense = 0;
                _removeMapping(2, station.owner, station.stationId);
                station.owner = msg.sender;
                playerStations[msg.sender].push(station.stationId);
            } else {
                station.defense -= _amt;
            }
        } else if (_type == 3) {
            Sector storage sector = galaxyMap[_id];
            require(msg.sender != sector.owner);
            require(ownsSector[msg.sender] == false);
            if (sector.defense <= _amt) {
                sector.defense = 0;
                ownsSector[sector.owner] = false;
                ownsSector[msg.sender] = true;
                sector.owner = msg.sender;
            } else {
                sector.defense -= _amt;
            }
        } else { revert(); }
        emit AssetAttacked(_id, _type, _amt);
    }
    
    function assetDefend(uint8 _type, uint32 _id, uint256 _amt) public {  //Send drones to defend asset.
        require(droneBalances[msg.sender] >= _amt);
        droneBalances[msg.sender] -= _amt;
        if (_type == 0) {
            Star storage star = starCollection[_id];
            star.defense += _amt;
        } else if (_type == 1) {
            Planet storage planet = planetCollection[_id];
            planet.defense += _amt;
        } else if (_type == 2) {
            Station storage station = stationCollection[_id];
            station.defense += _amt;
        } else if (_type == 3) {
            Sector storage sector = galaxyMap[_id];
            sector.defense += _amt;
        } else { revert();}
        emit AssetDefended(_id, _type, _amt);
    }
    
    function blackholeStart(uint8 _id, uint8 _max, uint8 _materialId, uint256 _time) public {  //Allows blackhole owner to start new round
        Blackhole storage blackhole = blackholeCollection[_id];
        require(_materialId > 0);
        require(_materialId <= totalMaterials);
        require(blackhole.owner == msg.sender);
        require(blackhole.active == false);
        blackhole.maxPlayers = _max;
        blackhole.materialId = _materialId;
        blackhole.startTime = block.number;
        blackhole.endTime = block.number + _time;
        blackhole.active = true;
        emit BlackholeStarted(_id, _materialId, _max);
    }
    
    function blackholePlay(uint8 _id, uint256 _amt) public {  //Allows address to play in blackhole round
        Blackhole storage blackhole = blackholeCollection[_id];
        Material storage material = materialCollection[blackhole.materialId];
        require(blackhole.active == true);
        require(blackhole.currentPlayers < blackhole.maxPlayers);
        require(block.number > blackhole.startTime);
        require(block.number < blackhole.endTime);
        require(material.balances[msg.sender] >= _amt);
        for (uint i = 0; i < blackhole.players.length; i++) {
            if (blackhole.players[i] == msg.sender) {
                revert();
            }
        }
        material.balances[msg.sender] -= _amt;
        blackhole.players.push(msg.sender);
        blackhole.currentPlayers++;
        blackhole.amount[msg.sender] = _amt;
        blackhole.store += _amt;
        emit BlackholePlayed(_id, _amt);
    }
    
    function blackholeEnd(uint8 _id) public {  //Allows owner to finalize round after endTime
        Blackhole storage blackhole = blackholeCollection[_id];
        Material storage material = materialCollection[blackhole.materialId];
        require(msg.sender == blackhole.owner);
        require(blackhole.active == true);
        require(block.number > blackhole.endTime);
        blackhole.active = false;
        uint256 tax = (blackhole.store / 10);
        uint256 winnings = blackhole.store - tax;
        blackhole.store = 0;
        address winner = blackhole.players[_random(blackhole.currentPlayers)];
        material.balances[winner] += winnings;
        material.balances[blackhole.owner] += tax;
        for (uint i = 0; i < blackhole.players.length; i++) {
            blackhole.amount[blackhole.players[i]] = 0;
            delete blackhole.players[i];
        }
        blackhole.players.length = 0;
        blackhole.currentPlayers = 0;
        emit BlackholeEnded(_id, winner);
    }
    
    //////
    
    //Ship Usage Functions//
    
    function shipMove(uint32 _shipId, uint8 _dir) public {  //Allows ship movement on galaxyMap. Border restricts movement to 15x15 grid.
        Ship storage ship = shipCollection[_shipId];
        Sector memory sector = galaxyMap[ship.sectorId];
        require(msg.sender == ship.owner);
        require(ship.hull >= 1);
        require(ship.energy >= 1);
        ship.energy--;
        ship.docked = false;
        if (_dir == 2) {
            require(sector.border != 4);
            require(sector.sectorId != 211);
            require(sector.sectorId != 225);
            ship.sectorId += 15;
        } else if (_dir == 4) {
            require(sector.border != 3);
            require(sector.sectorId != 1);
            ship.sectorId -= 1;
        } else if (_dir == 6) {
            require(sector.border != 2);
            require(sector.sectorId != 15);
            ship.sectorId += 1;
        } else if (_dir == 8) {
            require(sector.border != 1);
            ship.sectorId -= 15;
        } else if (_dir == 1) {
            require(sector.border != 4);
            require(sector.border != 3);
            require(sector.sectorId != 1);
            require(sector.sectorId != 211);
            require(sector.sectorId != 225);
            ship.sectorId += 14;
        } else if (_dir == 3) {
            require(sector.border != 4);
            require(sector.border != 2);
            require(sector.sectorId != 15);
            require(sector.sectorId != 211);
            require(sector.sectorId != 225);
            ship.sectorId += 16;
        } else if (_dir == 7) {
            require(sector.border != 1);
            require(sector.border != 3);
            require(sector.sectorId != 1);
            require(sector.sectorId != 15);
            require(sector.sectorId != 211);
            ship.sectorId -= 16;
        } else if (_dir == 9) {
            require(sector.border != 1);
            require(sector.border != 2);
            require(sector.sectorId != 1);
            require(sector.sectorId != 15);
            require(sector.sectorId != 225);
            ship.sectorId -= 14;
        } else if (_dir == 5) {
            require(sector.wormholeId != 0);
            ship.sectorId = sector.wormholeId;
        } else { revert(); }
        emit ShipMoved(_shipId, _dir, ship.sectorId);
    }
    
    function shipExplore(uint32 _shipId) public {  //Ship explores area, finds stuff maybe. Can find sector's wormhole (if not found), or a blackhole, or something
        Ship storage ship = shipCollection[_shipId];
        require(msg.sender == ship.owner);
        require(block.number - ship.exploreTime > exploreCooldown);
        require(ship.energy >= 1);
        require(ship.hull >= 1);
        if (ship.docked == true) {ship.docked = false;}
        uint rand = _random(100);
        ship.energy--;
        ship.exploreTime = block.number;
        if (rand > 95 ) {  //If sector's wormhole not found, finds it, if it is, the ships owner gets a blackhole. Allows wormholes to be discovered first
            Sector memory sector = galaxyMap[ship.sectorId];
            if (sector.wormholeId == 0) {
                sector.wormholeId = uint8(_random(225));
            } else {
                require(ownsBlackhole[ship.owner] == false);
                require(totalBlackholes < 250);
                ownsBlackhole[ship.owner] = true;
                totalBlackholes++;
                Blackhole storage blackhole = blackholeCollection[totalBlackholes];
                blackhole.owner = ship.owner;
                blackhole.blackholeId = totalBlackholes;
                //blackhole.discoverTime = block.number;
            }
            emit ShipExplored(_shipId, 1, ship.sectorId);
        } else if (rand > 70 && rand < 95) {  //Ship's energy refilled to maximum amount
            ship.energy = ship.level * 10;
            emit ShipExplored(_shipId, 2, ship.sectorId);
        } else if (rand > 45 && rand < 70) {  //Free stuff
            Material storage material = materialCollection[uint8(_random(5))];
            material.balances[ship.owner]++;
            emit ShipExplored(_shipId, 3, ship.sectorId);
        } else {  //Meh
            energyBalances[ship.owner] += 10;
            emit ShipExplored(_shipId, 4, ship.sectorId);
        }
    }
    
    function shipRefuel(uint32 _shipId) public {  //Refuels ship, must be docked in station/planet you own
        Ship storage ship = shipCollection[_shipId];
        require(msg.sender == ship.owner);
        require(ship.docked == true);
        uint256 refillAmt = (ship.level * 10) - ship.energy;
        require(refillAmt > 0);
        require(energyBalances[ship.owner] >= refillAmt);
        energyBalances[ship.owner] -= refillAmt;
        ship.energy += refillAmt;
        emit ShipRefueled(_shipId);
    }
    
    function shipRepair(uint32 _shipId) public {  //Repairs ship hull to maxHull
        Ship storage ship = shipCollection[_shipId];
        require(msg.sender == ship.owner);
        require(ship.docked == true);
        //require(creditBalances[msg.sender] >= 10);
        //creditBalances[msg.sender] -= 10;
        ship.hull = ship.maxHull;
        emit ShipRepaired(_shipId);
    }
    
    function shipDock(uint32 _shipId, bool _planetOrStation, uint32 _id) public {  //Docks ship in target station/planet for refuel/repair
        Ship storage ship = shipCollection[_shipId];
        require(msg.sender == ship.owner);
        if (_planetOrStation == true) {
            Planet storage planet = planetCollection[_id];
            require(msg.sender == planet.owner);
            require(ship.sectorId == planet.sectorId);
        } else {
            Station storage station = stationCollection[_id];
            require(msg.sender == station.owner);
            require(ship.sectorId == station.sectorId);
        }
        ship.docked = true;
        emit ShipDocked(_shipId, _planetOrStation, _id);
    }
    
    //////
    
    //Game Functions//
    
    function freeStuff() public {  //Testing function I'll probably remove
        require(playedBefore[msg.sender] == false);
        playedBefore[msg.sender] = true;
        energyBalances[msg.sender] += 555;
        //creditBalances[msg.sender] += 10;
        Material storage material = materialCollection[1];
        material.balances[msg.sender] += 50;
    }
    
    function addNewMaterial(uint8 _level) public {  //Allows owner to add new material
        require(msg.sender == owner);
        totalMaterials++;
        Material storage material = materialCollection[totalMaterials];
        //material.materialId = totalMaterials;
        material.level = _level;
    }
    
    function _random(uint _max) internal returns (uint) {  //Internal function for RNG. Probably not secure but there's no money on the line so please don't cheat
        nonce++;
        uint randomHash = uint(keccak256(block.blockhash(block.number-1)))+nonce;
        return (randomHash % _max)+1;
    }
    
    function _shipDamage(uint32 _shipId, uint16 _amt) internal {  //Internal function for damaging ship, checks if has shield, then if ship destroyed
        Ship storage ship = shipCollection[_shipId];
        if (ship.shield > 0) {
            if (ship.shield >= _amt) {
                ship.shield -= _amt;
            } else {
                uint16 post = _amt - ship.shield;
                ship.shield = 0;
                if (post >= ship.hull) {
                    ship.hull = 0;
                    ship.docked = true;
                } else {
                    ship.hull -= post;
                }
            }
        }
    }
    
    function _removeMapping(uint8 _type, address _address, uint32 _id) internal {  //Internal function for removing ID's from arrays (used in object ownership tranfers)
        uint foundIndex = 0;
        if (_type == 0) {
            uint32[] storage objIdList = playerStars[_address];
            for (; foundIndex < objIdList.length; foundIndex++) {
                if (objIdList[foundIndex] == _id) {
                    break;
                }
            }
            if (foundIndex < objIdList.length) {
                objIdList[foundIndex] = objIdList[objIdList.length-1];
                delete objIdList[objIdList.length-1];
                objIdList.length--;
            }
        } else if (_type == 1) {
            uint32[] storage objIdList1 = playerPlanets[_address];
            for (; foundIndex < objIdList1.length; foundIndex++) {
                if (objIdList1[foundIndex] == _id) {
                    break;
                }
            }
            if (foundIndex < objIdList1.length) {
                objIdList1[foundIndex] = objIdList1[objIdList.length-1];
                delete objIdList1[objIdList1.length-1];
                objIdList1.length--;
            }
        } else if (_type == 2) {
            uint32[] storage objIdList2 = playerStations[_address];
            for (; foundIndex < objIdList2.length; foundIndex++) {
                if (objIdList2[foundIndex] == _id) {
                    break;
                }
            }
            if (foundIndex < objIdList2.length) {
                objIdList2[foundIndex] = objIdList2[objIdList.length-1];
                delete objIdList2[objIdList2.length-1];
                objIdList2.length--;
            }
        } else if (_type == 3) {
            uint32[] storage objIdList3 = playerShips[_address];
            for (; foundIndex < objIdList3.length; foundIndex++) {
                if (objIdList3[foundIndex] == _id) {
                    break;
                }
            }
            if (foundIndex < objIdList.length) {
                objIdList3[foundIndex] = objIdList3[objIdList3.length-1];
                delete objIdList3[objIdList3.length-1];
                objIdList3.length--;
            }
        } else if (_type == 4) {
            uint32[] storage objIdList4 = playerShips[_address];
            for (; foundIndex < objIdList4.length; foundIndex++) {
                if (objIdList4[foundIndex] == _id) {
                    break;
                }
            }
            if (foundIndex < objIdList.length) {
                objIdList4[foundIndex] = objIdList4[objIdList4.length-1];
                delete objIdList4[objIdList4.length-1];
                objIdList4.length--;
            } 
        }
    }

    function changeCooldown(uint8 _type, uint256 _amt) public {
        require(msg.sender == owner);
        require(_amt > 0);
        if (_type == 0) {
            produceCooldown = _amt;
        } else if (_type == 1) {
            exploreCooldown = _amt;
        } else if (_type == 2) {
            starsPerSectorLevel = _amt;
        }
    }
    
    function withdraw() public {
        require(msg.sender == owner);
        owner.transfer(address(this).balance);
    }
    
    //////
    
    //Read Functions//
    
    function getPlayerStars() public view returns (uint32[]) {
        return playerStars[msg.sender];
    }
    
    function getPlayerPlanets() public view returns (uint32[]) {
        return playerPlanets[msg.sender];
    }
    
    function getPlayerStations() public view returns (uint32[]) {
        return playerStations[msg.sender];
    }
    
    function getPlayerShips() public view returns (uint32[]) {
        return playerShips[msg.sender];
    }
    
    function getSectorStars(uint8 _sectorId) public view returns (uint32[]) {
        Sector memory sector = galaxyMap[_sectorId];
        return(sector.stars);
    }
    
    function getStarAssets(uint32 _starId) public view returns (uint32[], uint32[]) {
        Star memory star = starCollection[_starId];
        return(star.planets, star.stations);
    }
}