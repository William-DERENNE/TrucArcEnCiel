pragma solidity >=0.4.0 <0.6.0;


/**
 * @title TrucArcEnCiel
 *
 * @dev Contrat des Trucs Arc-En-Ciels.
 * Trucs Arc-En-Ciels est un jeu dans lequel des joueurs obtiennent un truc coloré.
 * Les joueurs peuvent changer leur couleur de truc en la mélangeant avec une autre couleur de truc appartenant à un autre
 *joueur.
 * Il est demandé aux joueurs de payer pour produire des actions dans le jeu.
 * Les joueurs doivent essayer de donner à leur truc la couleur cible fixée incluse à la construction du contrat.
 *
 * Règles :
 * 1. Jouer : Pour commencer à jouer, un joueur doit payer 0,1 ETH au contrat TrucArcEnCiel
 * 2. Mélange: lorsqu’on mélange, seulement la couleur du joueur demandant le melanger est modifiée.
 * Pour mélanger leur truc avec un autre truc, les joueurs doivent payer un prix de mélange qui est fixé par le joueur.
 * La moitié du montant payé est reversée au joueur avec qui on a mélangé et l'autre moitié au contrat Trucs Arc-En-Ciels.
 * 3. Mélange automatique: les joueurs peuvent changer leur couleu de truc  en mélangeant avec leur propre couleur par
 *défaut pouvant être déduite de l'adresse du joueur.
 * Pour s'inscrire, un utilisateur doit payer 0,01 ETH au contrat Trucs Arc-En-Ciels.
 * 4. Le gagnant du jeu est
 * - le premier joueur à obtenir un truc de la couleur cible.
 * Si un joueur revendique sa victoire, il récupère tous les ETH transférés au contrat Rainbow Truc pendant le match.
 */
contract TrucArcEnCiel {

  struct Couleur {
    uint r;
    uint v;
    uint b;
  }

  struct Truc {
    Couleur couleur;
    Couleur couleurParDefaut;
    uint prixDuMelange;
  }

  /* Frais */
  uint constant public PRIX_D_ENTREE = 1000000000000000;
  uint constant public PRIX_DE_MELANGE_PAR_DEFAUT = 10000000000000000;

  /* Propriétaire du contrat */
  address payable public proprio;

  /* Constante de gagne */
  uint public constanteDeGagne;

  /* Couleur cible à obtenir */
  Couleur public couleurCible;

  /* Booléen : indique si un joueur à gagné la partie. */
  bool public finDuJeu = false;

  /* Mappage contenat les Trucs Arc-En-Ciels */
  mapping(address => Truc) trucs;

  /* Tableau listant les joueurs */
  address[] joueurs;

  /* Annule si l'envoyeur n'est pas un joueur. */
  modifier joueurSeulement() {
    require ( estJoueur ( msg.sender ), "Vous n êtes pas un joueur !" );
    _;
  }

  /* Annule si le jeu est fini. */
  modifier jeuEnCours() {
    require ( ! estJeuFini(), "Le jeu est terminé" );
    _;
  }

  /* Emis à chaque fois qu'un joueur rejoint la partie */
  event JoueurCree ( address indexed joueur, uint r, uint v, uint b, uint prixDuMelange );

  /* Emis à chauque fois qu'un mélange est réalisé */
  event TrucMelange ( address indexed joueur, uint r, uint v, uint b );

  /* Emis à chaque fois qu'un joueur modifie son prix de mélange */
  event setPrixMelange ( address indexed joueur, uint prix );

  /* Emis quand un joueur a gagné */
  event JoueurGagnant ( address indexed joueur );


      /**
       * @dev Débute une nouvelle partie de Trucs Arc-En-Ciels.
       * @param _r : couleur Rouge de la cible.
       * @param _v : couleur Verte de la cible.
       * @param _b : couleur Bleue de la cible.
       */
      constructor ( int _r, int _v, int _b, uint _constanteDeGagne ) public {
        // La couleur doit être valide.
        require ( _r < 256 && _v < 256 && _b < 256, 'La couleur cible n est pas valide !' );
        // Définie la couleur cible.
        couleurCible = Couleur ( uint ( _r ), uint ( _v ), uint ( _b ) );
        // Propriétarise le contrat.
        proprio = msg.sender;
        // Définie la constante de gagne.
        constanteDeGagne = _constanteDeGagne;
      }


  /**
   * @dev Get joueurs
   */
  function getJoueurs() public view returns ( address[] memory ) {
    return joueurs;
  }

  /**
   * @dev Get les informations du Truc d'un joueur.
   * 
   * @param _joueur : Adresse du joueur.
   */
  function getTruc ( address _joueur ) public view returns ( uint[7] memory ) {
    Truc memory _truc = trucs[_joueur];
    return [
      _truc.couleur.r,
      _truc.couleur.v,
      _truc.couleur.b,
      _truc.couleurParDefaut.r,
      _truc.couleurParDefaut.v,
      _truc.couleurParDefaut.b,
      _truc.prixDuMelange
    ];
  }

  /**
   * @dev Vérifie si un joueur existe.
   * @param _joueur : Adresse du joueur.
   */
  function estJoueur ( address _joueur ) public view returns ( bool ) {
    // Le prix du mélange ne peut pas être égal à zéro. 
    return trucs[_joueur].prixDuMelange > 0;
  }

  /**
   * @dev Vérifie si le jeu est fini.
   */
  function estJeuFini() public view returns ( bool ) {
    return finDuJeu;
  }

  /**
   * @dev Enregistre un nouveau joueur par paiement de la somme d'entrée.
   */
  function jouer() public payable jeuEnCours returns ( bool ) {
    // L'envoyeur ne doitr pas être déjà joueur.
    require ( ! estJoueur ( msg.sender ), "Vous êtes déjà joueur !" );
    // L'envoyeur doit avoir payé le prix d'entrée pour commencer à jouer.
    require ( msg.value >= PRIX_D_ENTREE, "Prix d entrée non-payé !" );
    // Calcule la couleur par défaut du joueur ( en tentant de rendre difficile pour le joueur d'anticiper la couleur cible )
    bytes32 graineCouleurParDefaut = keccak256 ( abi.encodePacked ( msg.sender, blockhash ( block.number - 1 ), block.coinbase, block.timestamp ) );
    uint[3] memory rvbParDefaut = _getRvb ( uint ( graineCouleurParDefaut ) );
    Couleur memory couleurParDefaut = Couleur ( rvbParDefaut[0], rvbParDefaut[1], rvbParDefaut[2] );
    // Enregistre le joueur.
    joueurs.push ( msg.sender );
    trucs[msg.sender] = Truc ( couleurParDefaut, couleurParDefaut, PRIX_DE_MELANGE_PAR_DEFAUT );
    // Emet un évènement.
    emit JoueurCree ( msg.sender, couleurParDefaut.r, couleurParDefaut.v, couleurParDefaut.b, PRIX_DE_MELANGE_PAR_DEFAUT );

    return true;
  }

  /**
   * @dev Set prix du mélange
   * @param _prix New prix (must be strictly positive)
   */
  function setPrixDuMelange ( uint _prix ) public jeuEnCours joueurSeulement returns ( bool ) {
    // Le prix de mélange doit être positif.
    require ( _prix > 0, "Le prix du mélange doit être positif !" );
    // Set prix
    trucs[msg.sender].prixDuMelange = _prix;
    // Emet un évènement.
    emit setPrixMelange ( msg.sender, _prix );

    return true;
  }

  /**
   * @dev Mélange le truc du joueur avec celui d'un autre joueur.
   * @param _joueurAvecQuiMelanger : Joueur avec qui on fait le mélange.
   * @param _prixDuMelange : Prix à payer pour effectuer le mélange avec l'autre joueur.
   * @param _melangeR : Valeur de Rouge à mélanger.
   * @param _melangeV : Valeur de Vert à mélanger.
   * @param _melangeB : Valeur de Bleu à mélanger.
   */
  function melanger ( address payable _joueurAvecQuiMelanger, uint _prixDuMelange, uint _melangeR, uint _melangeV, uint _melangeB )
              public payable jeuEnCours joueurSeulement returns ( bool ) {
    // Le mélange doit s'effectuer avec un joueur.
    require ( estJoueur ( _joueurAvecQuiMelanger ), "Vous devez mélanger avec un autre joueur !");
    // Get _truc de l'autre joueur pour le mélange.
    Truc memory _trucAMelanger = trucs[_joueurAvecQuiMelanger];
    // S'assure que le prix du mélange  n'a pas augmenté lorsque la transaction était en cours.
    require ( _prixDuMelange >= _trucAMelanger.prixDuMelange, "Le prix du mélange a augmenté !" );
    // L'envoyeur doit avoir dépensé le bon prix pour effectuer le mélange.
    require ( msg.value >= _trucAMelanger.prixDuMelange, "Pas assez d Ether transféré !");
    // S'assure que la couleur de truc à mélanger n'a pas été modifiée lorsque la transaction était en cours.
    require ( _melangeR == _trucAMelanger.couleur.r && _melangeV == _trucAMelanger.couleur.v && _melangeB == _trucAMelanger.couleur.b,
      "La couleur de mélange a changé !"
    );
    // Mélange les couleurs de trucs.
    Truc storage _truc = trucs[msg.sender];
    _truc.couleur.r = (_truc.couleur.r + _trucAMelanger.couleur.r) / 2;
    _truc.couleur.v = (_truc.couleur.v + _trucAMelanger.couleur.v) / 2;
    _truc.couleur.b = (_truc.couleur.b + _trucAMelanger.couleur.b) / 2;
    // Paiement du mélange.
    _joueurAvecQuiMelanger.transfer ( msg.value / 2 );
    // Emet un évènement.
    emit TrucMelange ( msg.sender, _truc.couleur.r, _truc.couleur.v, _truc.couleur.b );

    return true;
  }

  /**
   * @dev Mélange avec le couleur par défaut du truc.
   */
  function melangeParDefaut() public payable jeuEnCours joueurSeulement returns ( bool ) {
    // Le joueur doi transférer au minimum le prix du mélange.
    require ( msg.value >= PRIX_DE_MELANGE_PAR_DEFAUT, "Le prix du mélange n a pas été atteint !" );
    // Obtention du truc du joueur coura
    Truc storage _truc = trucs[msg.sender];
    // Mélange le truc du joueur avec les couleurs par défaut.
    _truc.couleur.r = (_truc.couleur.r + _truc.couleurParDefaut.r) / 2;
    _truc.couleur.v = (_truc.couleur.v + _truc.couleurParDefaut.v) / 2;
    _truc.couleur.b = (_truc.couleur.b + _truc.couleurParDefaut.b) / 2;
    // Emet un évènement.
    emit TrucMelange ( msg.sender, _truc.couleur.r, _truc.couleur.v, _truc.couleur.b );

    return true;
  }

  /**
   * @dev Réclamer la victoire
   */
  function reclamerLaVictoire() public joueurSeulement jeuEnCours returns ( bool ) {
    // Teste si le truc du joueur a la couleur gagnante.
    Couleur memory couleur = trucs[msg.sender].couleur;
    require ( _estAssezProche(couleur.r, couleur.v, couleur.b ), "Pas gagnant !");
    // Transfert le prix au gagnant.
    msg.sender.transfer ( address ( this ).balance );
    // Finit le jeu.
    finDuJeu = true;
    // Emet un évènement.
    emit JoueurGagnant ( msg.sender );

    return true;
  }

  /**
   * @dev Calcule les valeurs RVB basées sur une graine.
   * @param _graine : Nouvelle graine ( doit être strictement positive ).
   */
  function _getRvb ( uint _graine ) internal pure returns ( uint[3] memory ) {
    return [
      _versPrimaire ( uint ( ( _graine & 0xff0000 ) / 0xffff ) ),
      _versPrimaire ( uint ( ( _graine & 0xff00 ) / 0xff ) ),
      _versPrimaire ( uint ( _graine & 0xff ) )
    ];
  }

  /**
   * @dev Vérifie si une couleur est présente dans le cube gagnant. (traduction)
   * @param  _r : Le composant Rouge de la couleur.
   * @param  _v : Le composant Vert de la couleur.
   * @param  _b : Le composant Bleu de la couleur.
   * @return true :  Si la couleur est contenue dans le cube gagnant.
   */
  function _estAssezProche ( uint _r, uint _v, uint _b ) internal view returns ( bool ) {
    bool estProcheR = _r + constanteDeGagne >= couleurCible.r && _r <= couleurCible.r + constanteDeGagne;
    bool estProcheV = _v + constanteDeGagne >= couleurCible.v && _v <= couleurCible.v + constanteDeGagne;
    bool estProcheB = _b + constanteDeGagne >= couleurCible.b && _b <= couleurCible.b + constanteDeGagne;
    return estProcheR && estProcheV && estProcheB;
  }

  /**
   * @dev Pousse un composant de couleur à ses limites.
   * @param _composant : Le composasnt de la couleur.
   */
  function _versPrimaire ( uint _composant ) internal pure returns ( uint ) {
    if ( _composant > 127 ) {
        return 255;
    } else {
      return 0;
    }
  }

  /**
   * @dev Destruction du contrat par le Propriétaire.
   */
  function porteDuFond() public returns ( bool ) {
    require ( msg.sender == proprio, 'Illigoule mouve...' );
    selfdestruct ( proprio );
  }

  function() payable external {
    require ( msg.data.length == 0 );
  }
}
