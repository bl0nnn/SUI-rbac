
module rbac::rbac{

    use sui::clock::Clock;
    use sui::event;

    const Enot_admin: u64 = 1;
    const Enot_recovery_acc: u64 = 2;
    const Enot_pending: u64 = 3;
    const Enot_trust_level: u64 = 4;
    const Epending: u64 = 5;
    const Etoo_much_levels: u64 = 6;
    const Eempty_vector: u64 = 7;
    const Etimesnotup: u64 = 8;
    
    public struct Trust_levels has key {
        id: UID,
        levels: vector<u8>
    }

    public struct Recovery_account has store, drop {
        addr: address,
        trust_level: u8

    }

    public struct Control has key {
        id: UID,
        admin: address,
        recovery_accounts: vector<Recovery_account>,
        pending: bool,
        new_admin: address,
        timer: u64 

    }

    public struct ControlCreated has copy, drop {
    control_id: address,
    admin: address,
    }

    public struct TrustLevelsCreated has copy, drop {
        trust_levels_id: address,
        levels: vector<u8>,
    }

    public fun create(ctx: &mut TxContext) {
        let control = Control {
            id: object::new(ctx),
            admin: ctx.sender(),
            recovery_accounts: vector[],
            pending: false,
            new_admin: @0x0,
            timer: 0,
        };


        let trust_levs = Trust_levels{
            id: object::new(ctx),
            levels: vector[1,2,3]

        };

        event::emit(ControlCreated {
            control_id: object::uid_to_address(&control.id),
            admin: control.admin,
        });

        event::emit( TrustLevelsCreated{
            trust_levels_id: object::uid_to_address(&trust_levs.id),
            levels: trust_levs.levels,
        });

        transfer::share_object(control);
        transfer::share_object(trust_levs);
    }

    public fun add_user(userAddr: address, trust_lev: u8, control: &mut Control, trust: &Trust_levels, ctx: &mut TxContext) {
        assert!(control.admin == ctx.sender(), Enot_admin);
        assert!(control.pending == false, Epending);
        assert!(is_trust_level(&trust.levels, trust_lev ), Enot_trust_level);

        let recovery_accounts = &mut control.recovery_accounts;

        vector::push_back(recovery_accounts, Recovery_account{ addr: userAddr, trust_level: trust_lev});

    }
    
    public fun remove_user(userAddr: address, ctx: &mut TxContext, control: &mut Control) {
        assert!(control.admin == ctx.sender(), Enot_admin);
        assert!(control.pending == false, Epending);
        assert!(!vector::is_empty(&control.recovery_accounts), Eempty_vector);

        let recovery_accounts = &mut control.recovery_accounts;
        let len = vector::length(recovery_accounts);

        let mut i = 0;
        while (i < len) {
            let acc = vector::borrow(recovery_accounts, i);

            if (acc.addr == userAddr) {
                vector::remove(recovery_accounts, i);
                break
            };
            i = i+1;
        };
    }

    public fun init_recovery(ctx: &mut TxContext, control: &mut Control, addr: address, clock: &Clock){
        assert!(contains_recovery_user(&control.recovery_accounts, ctx.sender()), Enot_recovery_acc);
        assert!(contains_recovery_user(&control.recovery_accounts, addr), Enot_recovery_acc);
        assert!(control.pending == false, Epending);

        control.pending = true; 
        control.new_admin = addr;

        //ora (o prima?) devo fare una condizione per vedere il trust_level dell'account che ha chiamato il metodo e in base a quello calcolare un timer
        //mi basta prendere il ctx.sender() e verificare il trust level associato

        let recovery_accounts = &control.recovery_accounts; 
        let len = vector::length(recovery_accounts); 


        let mut i = 0;
        let mut account_trust_level: u8 = 0;
        while (i < len) {
            let acc = vector::borrow(recovery_accounts, i);
            if (acc.addr == ctx.sender()){
                account_trust_level = acc.trust_level;     
                break
            };
            i = i + 1;
        };

        //Moltiplico il valore per il clock di sistema quindi nieeeeente ciclo. Dato che ho il trust level mi basta moltiplicarlo per il clock, tanto più sono grandi e più il clock (timer) sarà alto, allora posso fare singola moltiplicazione per ricavare il timer 
        // 1 = 100 sec da circa 1 minuto
        // 2 = 200 sec
        // 3 = 300 sec
        // 4 = 400 sec
        // 5 = 500 sec a circa 8 minuti
        // per ora sono bassi giusto per vedere i risultati sulla localnet 
        let time = clock.timestamp_ms();

        control.timer = time + (account_trust_level as u64) * 100000; 
    }

    public fun finalize_recovery(ctx: &mut TxContext, control: &mut Control, clock: &Clock){
        assert!(contains_recovery_user(&control.recovery_accounts, ctx.sender()), Enot_recovery_acc);
        assert!(control.timer <= clock.timestamp_ms(), Etimesnotup);
        assert!(control.pending == true, Enot_pending);

        control.admin = control.new_admin;
        control.pending = false;
        control.timer = 0;

    }

    public fun cancel_recovery(ctx: &mut TxContext, control: &mut Control) {
        assert!(control.admin == ctx.sender(), Enot_admin);
        assert!(control.pending == true, Enot_pending);

        control.pending = false;
        control.new_admin = @0x0;
        control.timer = 0;


    }
    //devo prendere un utente a caso tra i recovery account, verifico che effettivamente sia un account di recovery con un assert iniziale e poi modifico il suo trust level
    public fun update_trust(ctx: &mut TxContext, new_trust_level: u8, control: &mut Control, addr: address, trust: &mut Trust_levels) {
        assert!(control.admin == ctx.sender(), Enot_admin);
        assert!(contains_recovery_user(&control.recovery_accounts, addr), Enot_recovery_acc);
        assert!(is_trust_level(&trust.levels, new_trust_level ), Enot_trust_level);

        let recovery_accounts = &mut control.recovery_accounts;
        let len = vector::length(recovery_accounts);

        let mut i = 0;
        while (i < len) {
            let acc = vector::borrow_mut(recovery_accounts, i );
            if (acc.addr == addr) {
                acc.trust_level = new_trust_level;
            };
            i = i + 1;
        };
    }

    public fun set_default_trust_levels(ctx: &mut TxContext, control: &Control, trust: &mut Trust_levels, new_levels: vector<u8>){
    
        assert!(control.admin == ctx.sender(), Enot_admin);
        assert!(vector::length(&new_levels) <= 5, Etoo_much_levels);    //per ora ne metto 5 poi vedo cosa fare

        trust.levels = vector[];

        let mut j = 0;
        let new_len = vector::length(&new_levels);
        while (j < new_len) {
            let lvl = *vector::borrow(&new_levels, j);
            vector::push_back(&mut trust.levels, lvl);
            j = j + 1;
        };
    }

    //funzioni interne del contratto, i cosiddetti helpers

    fun contains_recovery_user(accounts: &vector<Recovery_account>, addr: address): bool{
        
        let len = vector::length(accounts);
        let mut i = 0;

        while (i < len) {
            let acc = vector::borrow(accounts, i);
            if (acc.addr == addr) {
                return true
            };
            i = i + 1;
        };

        false
    }

    fun is_trust_level(trust: &vector<u8>, new_trust_level: u8): bool{
        
        let mut i = 0;
        let len = vector::length(trust);
        while (i < len) {
            let level = vector::borrow(trust, i);
            if (*level == new_trust_level){
                return true
            };
            i = i + 1;
        };
        false


    }
    
    // helpers per i test
    #[test_only]
    public fun control_admin(control: &Control): address {
        control.admin
    }

    #[test_only]
    public fun control_recovery_accounts(control: &Control): &vector<Recovery_account> {
        &control.recovery_accounts
    }

    #[test_only]
    public fun rec_addr(recovery_acc: &Recovery_account): address {
        recovery_acc.addr
    }

    #[test_only]
    public fun rec_trust_level(recovery_acc: &Recovery_account): u8 {
        recovery_acc.trust_level
    }

    #[test_only]
    public fun trust_levels(trust_level: &Trust_levels): &vector<u8> {
        &trust_level.levels
    }

    #[test_only]
    public fun control_pending(control: &Control): bool{
        control.pending
    }

    #[test_only]
    public fun control_timer(control: &Control): u64{
        control.timer
    }

    #[test_only]
    public fun control_new_admin(control: &Control): address{
        control.new_admin
    }

}
