{dotfilesLib}:
dotfilesLib.forAllSystems (system: (dotfilesLib.pkgsForSystem {inherit system;}).alejandra)
