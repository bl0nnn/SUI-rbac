#[test_only]
module rbac::rbac_tests {
    use rbac::rbac;
    use sui::test_scenario;

    const BLON: address = @0xAAA;
    const ALICE: address = @0xBBB;
    const BOB: address = @0xCCC;


    #[test]
    fun test_add_user(){
        let admin = BLON;
        let user = BOB;
        let mut scenario = test_scenario::begin(admin);

        {
            let ctx = test_scenario::ctx(&mut scenario);
            rbac::test_create(ctx);
        };

        test_scenario::next_tx(&mut scenario, admin);

        {
            let mut control = test_scenario::take_shared<rbac::Control>(&scenario);
            let trust = test_scenario::take_shared<rbac::Trust_levels>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            
            rbac::add_user(user , 1, ctx, &mut control, &trust);

            test_scenario::return_shared(control);
            test_scenario::return_shared(trust);
            
        };

        test_scenario::end(scenario);

    }

    
    
    
}