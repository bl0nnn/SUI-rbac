#[test_only]
module rbac::rbac_tests;

use rbac::rbac;
use sui::test_scenario::{Self as ts, Scenario};
use sui::clock;


const ADMIN: address = @0xA;
const USER1: address = @0xB;
const USER2: address = @0xC;

//prima mi faccio un po di helpers giusto per chiamarmi le funzioni 

fun call_add_user(ts: &mut Scenario, sender: address, user: address, trust: u8){
    ts.next_tx(sender);

    let mut control: rbac::Control = ts.take_shared();
    let trust_levels: rbac::Trust_levels = ts.take_shared();

    rbac::add_user(user, trust, &mut control, &trust_levels, ts.ctx());
    ts::return_shared(control);
    ts::return_shared(trust_levels);
}

fun call_remove_user(ts: &mut Scenario, sender: address, user: address){
    ts.next_tx(sender);

    let mut control: rbac::Control = ts.take_shared();

    rbac::remove_user(user, ts.ctx(), &mut control);
    ts::return_shared(control);

}

fun call_init_recovery(ts: &mut Scenario, sender: address, user: address){
    ts.next_tx(sender);

    let mut control: rbac::Control = ts.take_shared();
    let clock: sui::clock::Clock = ts.take_shared();


    rbac::init_recovery(ts.ctx(), &mut control, user, &clock);

    ts::return_shared(control);
    ts::return_shared(clock);


}

fun call_finalize_recovery(ts: &mut Scenario, sender: address){
    ts.next_tx(sender);
    
    let mut control: rbac::Control = ts.take_shared();
    let clock: sui::clock::Clock = ts.take_shared();

    rbac::finalize_recovery(ts.ctx(), &mut control, &clock);

    ts::return_shared(control);
    ts::return_shared(clock);
}

fun call_cancel_recovery(ts: &mut Scenario, sender: address){
    ts.next_tx(sender);

    let mut control: rbac::Control = ts.take_shared();

    rbac::cancel_recovery(ts.ctx(), &mut control);

    ts::return_shared(control);


}

fun call_update_trust(ts: &mut Scenario, sender: address, addr: address, new_trust_level: u8){
    ts.next_tx(sender);

    let mut control: rbac::Control = ts.take_shared();
    let mut trust_levels: rbac::Trust_levels = ts.take_shared();

    rbac::update_trust(ts.ctx(), new_trust_level, &mut control, addr, &mut trust_levels);

    ts::return_shared(control);
    ts::return_shared(trust_levels);
}

fun call_set_default_trust_levels(ts: &mut Scenario, new_levels: vector<u8>, sender: address){
    ts.next_tx(sender);

    let mut trust_levels: rbac::Trust_levels = ts.take_shared();
    let control: rbac::Control = ts.take_shared();

    rbac::set_default_trust_levels(ts.ctx(), &control, &mut trust_levels, new_levels);

    ts::return_shared(control);
    ts::return_shared(trust_levels);

}

//(primo test add_user) dovrei testare la add user anche su multipli utenti o basta 1 per assicurarsi che la logica funzioni? (chiedere a J)
#[test]
fun add_user_success(){
    let mut ts = ts::begin(ADMIN);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 2);

    ts.next_tx(ADMIN);

    let control: rbac::Control = ts.take_shared();
    assert!(rbac::control_admin(&control) == ADMIN, 0);

    let recs = rbac::control_recovery_accounts(&control);
    assert!(vector::length(recs) == 1, 0);

    let entry = &recs[0];
    assert!(rbac::rec_addr(entry) == USER1, 0);
    assert!(rbac::rec_trust_level(entry) == 2, 0);

    ts::return_shared(control);
    ts.end();
}

//(secondo test, non admin cerca di chiama add_user, dovrebbe fallire)
#[test]
#[expected_failure(abort_code = rbac::Enot_admin)]
fun add_user_not_admin(){
    let mut ts = ts::begin(ADMIN);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, USER1, USER2, 1);

    abort 0;
}

//(terzo test per veerificare l'inserimento di un trust level errato) per verificare il terzo assert
#[test]
#[expected_failure(abort_code = rbac::Enot_trust_level)]
fun add_user_invalid_trust(){
    let mut ts = ts::begin(ADMIN);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 4);

    abort 0;
}

#[test]
#[expected_failure(abort_code = rbac::Epending)]
fun add_user_on_pending(){
    let mut ts = ts::begin(ADMIN);

    let clock_obj = clock::create_for_testing(ts.ctx()); 
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 1);
    call_init_recovery(&mut ts, USER1, USER1);
    call_add_user(&mut ts, ADMIN, USER2, 1);

    abort 0;


}

#[test]
fun remove_user_success(){
    let mut ts = ts::begin(ADMIN);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 1);
    call_remove_user(&mut ts, ADMIN, USER1);
    
    ts.next_tx(ADMIN);

    let control: rbac::Control = ts.take_shared();
    assert!(rbac::control_admin(&control) == ADMIN, 0);

    let recs = rbac::control_recovery_accounts(&control);
    assert!(vector::length(recs) == 0, 0);

    ts::return_shared(control);
    ts.end();
}
#[test]
#[expected_failure(abort_code = rbac::Enot_admin)]
fun remove_user_not_admin(){
    
    let mut ts = ts::begin(ADMIN);
    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 1);
    call_remove_user(&mut ts, USER1, USER2);

    abort 0;


}

#[test]
#[expected_failure(abort_code = rbac::Eempty_vector)]
fun remove_user_empry_vector(){
    let mut ts = ts::begin(ADMIN);
    rbac::create(ts.ctx());
    call_remove_user(&mut ts, ADMIN, USER2);

    abort 0;


}

#[test]
#[expected_failure(abort_code = rbac::Epending)]
fun remove_user_on_pending(){
    let mut ts = ts::begin(ADMIN);

    let clock_obj = clock::create_for_testing(ts.ctx()); 
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 1);
    call_init_recovery(&mut ts, USER1, USER1);
    call_remove_user(&mut ts, ADMIN, USER1);

    abort 0;


}

#[test]
fun init_recovery_success(){
    let mut ts = ts::begin(ADMIN);
    
    let clock_obj = clock::create_for_testing(ts.ctx());      
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());

    call_add_user(&mut ts, ADMIN, USER1, 1);
    
    call_init_recovery(&mut ts, USER1, USER1);
    
    ts.next_tx(USER1);

    let clock_start: sui::clock::Clock = ts.take_shared();
    let start_time = clock_start.timestamp_ms();
    
    let control: rbac::Control = ts.take_shared();

    let recs = rbac::control_recovery_accounts(&control);
    let entry = &recs[0];


    assert!(rbac::control_admin(&control) == ADMIN, 0);
    
    assert!(rbac::control_pending(&control), 0);

    assert!(rbac::control_new_admin(&control) == USER1, 0);
    //l'idea è che io prenda la transazione in millisec al momento dell'invio della init e poi banalmento gli sommo la moltiplicazione del trust level con la costante 100k e la comparo con il timer presente nell'object control 
    assert!(rbac::control_timer(&control) == rbac::rec_trust_level(entry) as u64 * 100000 + start_time , 0);

    ts::return_shared(clock_start);
    ts::return_shared(control);
    ts.end();
}
#[test]
#[expected_failure(abort_code = rbac::Enot_recovery_acc)]
fun init_recovery_sender_not_recovery(){
    let mut ts = ts::begin(ADMIN);

    let clock_obj = clock::create_for_testing(ts.ctx());    //questa cosa di dover creare ogni volta l'oggetto clock è fastidiosa, forse mi conviene inizializzarlo nel contratto, oppure faccio due helpers, uno con clock e uno senza bho
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 1);
    call_init_recovery(&mut ts, ADMIN, USER1);

    abort 0;

}

#[test]
#[expected_failure(abort_code = rbac::Enot_recovery_acc)]
fun init_recovery_user_not_recovery(){
    let mut ts = ts::begin(ADMIN);

    let clock_obj = clock::create_for_testing(ts.ctx()); 
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 1);
    call_init_recovery(&mut ts, USER1, USER2);

    abort 0;

}

#[test]
#[expected_failure(abort_code = rbac::Epending)]
fun init_recovery_on_pending(){
    let mut ts = ts::begin(ADMIN);

    let clock_obj = clock::create_for_testing(ts.ctx()); 
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());

    call_add_user(&mut ts, ADMIN, USER1, 1);
    
    call_init_recovery(&mut ts, USER1, USER1);

    call_init_recovery(&mut ts, USER1, USER1);

    abort 0;

}

#[test]
fun finalize_recovery_success(){
    let mut ts = ts::begin(ADMIN);

    let clock_obj = clock::create_for_testing(ts.ctx()); 
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());

    call_add_user(&mut ts, ADMIN, USER1, 1);
    
    call_init_recovery(&mut ts, USER1, USER1);

    ts.next_tx(USER1);

    let mut clock_start: sui::clock::Clock = ts.take_shared();   
    let control: rbac::Control = ts.take_shared();
    //il mio problema è che se io mando la transazione di finalize recovery subito dopo init recovery naturalmente non sarà passato il tempo del timer
    //questo perché finalize_recovery fa un check sul tempo corrente e guarda se è maggiore o uguale al timer (cacolato come start_time + trust_level * 100k)
    //quindi prima di inviare la transazione finalize_recovery devo far si che l'oggetto tempo sia shiftato di di trust_level*100k in avanti (magari +1 per essere sicuri)

    let recs = rbac::control_recovery_accounts(&control);
    let entry = &recs[0];
    let user_trust_level = rbac::rec_trust_level(entry);

    let delta = user_trust_level as u64 * 100000 + 1;

    clock::increment_for_testing(&mut clock_start, delta);

    ts::return_shared(control);
    ts::return_shared(clock_start);

    call_finalize_recovery(&mut ts, USER1);
    
    ts.next_tx(USER1);
    
    let control2: rbac::Control = ts.take_shared();

    assert!(rbac::control_admin(&control2) == USER1, 0);
    assert!(rbac::control_pending(&control2) == false, 0);
    assert!(rbac::control_timer(&control2)==0, 0);

    ts::return_shared(control2);
    ts.end();

}
#[test]
#[expected_failure(abort_code=rbac::Enot_recovery_acc)]
fun finalize_recovery_not_recovery_acc(){
    let mut ts = ts::begin(ADMIN);

    let clock_obj = clock::create_for_testing(ts.ctx()); 
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());

    call_add_user(&mut ts, ADMIN, USER1, 1);
    
    call_init_recovery(&mut ts, USER1, USER1);

    ts.next_tx(USER1);

    let mut clock_start: sui::clock::Clock = ts.take_shared();
    let control: rbac::Control = ts.take_shared();

    let recs = rbac::control_recovery_accounts(&control);
    let entry = &recs[0];
    let user_trust_level = rbac::rec_trust_level(entry);

    let delta = user_trust_level as u64 * 100000 + 1;

    clock::increment_for_testing(&mut clock_start, delta);

    ts::return_shared(control);
    ts::return_shared(clock_start);

    call_finalize_recovery(&mut ts, ADMIN);

    abort 0;

}

#[test]
#[expected_failure(abort_code=rbac::Etimesnotup)]   //questo check dovrebbe implicare anche il test del'assert pending (anche perchè non posso failare questa condizione senza failarne un'atra)
fun finalize_recovery_time_is_not_up(){
    let mut ts = ts::begin(ADMIN);

    let clock_obj = clock::create_for_testing(ts.ctx()); 
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());

    call_add_user(&mut ts, ADMIN, USER1, 1);
    
    call_init_recovery(&mut ts, USER1, USER1);

    call_finalize_recovery(&mut ts, USER1);

    abort 0;

}

#[test]
fun cancel_recovery(){
    let mut ts = ts::begin(ADMIN);

    let clock_obj = clock::create_for_testing(ts.ctx()); 
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 1);
    call_init_recovery(&mut ts, USER1, USER1);

    call_cancel_recovery(&mut ts, ADMIN);

    ts.next_tx(USER1);

    let control: rbac::Control = ts.take_shared();

    assert!(rbac::control_pending(&control) == false, 0);

    assert!(rbac::control_new_admin(&control) == @0x0);

    assert!(rbac::control_timer(&control) == 0, 0);

    ts::return_shared(control);
    ts.end();

}

#[test]
#[expected_failure(abort_code=rbac::Enot_admin)]
fun cancel_recovery_not_admin(){
    let mut ts = ts::begin(ADMIN);

    let clock_obj = clock::create_for_testing(ts.ctx()); 
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 1);
    call_init_recovery(&mut ts, USER1, USER1);

    call_cancel_recovery(&mut ts, USER1);

    abort 0;
}

#[test]
#[expected_failure(abort_code=rbac::Enot_pending)]
fun cancel_recovery_not_pending(){
    let mut ts = ts::begin(ADMIN);

    let clock_obj = clock::create_for_testing(ts.ctx()); 
    clock::share_for_testing(clock_obj);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 1);

    call_cancel_recovery(&mut ts, ADMIN);

    abort 0;
}

#[test]
fun update_trust_success(){
    let mut ts = ts::begin(ADMIN);

    rbac::create(ts.ctx());

    call_add_user(&mut ts, ADMIN, USER1, 1);

    call_update_trust(&mut ts, ADMIN, USER1, 2);


    ts.next_tx(ADMIN);

    let control: rbac::Control = ts.take_shared();
    let recs = rbac::control_recovery_accounts(&control);
    let entry = &recs[0];

    let trust_level = rbac::rec_trust_level(entry);

    assert!(trust_level == 2, 0);

    ts::return_shared(control);
    ts.end();

}

#[test]
#[expected_failure(abort_code=rbac::Enot_admin)]
fun update_trust_not_admin(){

    let mut ts = ts::begin(ADMIN);

    rbac::create(ts.ctx());

    call_add_user(&mut ts, ADMIN, USER1, 1);

    call_update_trust(&mut ts, USER1, USER1, 2);

    abort 0;

}

#[test]
#[expected_failure(abort_code=rbac::Enot_recovery_acc)]
fun update_trust_not_recovery_user(){

    let mut ts = ts::begin(ADMIN);

    rbac::create(ts.ctx());

    call_update_trust(&mut ts, ADMIN, USER1, 2);

    abort 0;

}

#[test]
#[expected_failure(abort_code=rbac::Enot_trust_level)]

fun update_trust_not_trust_level(){

    let mut ts = ts::begin(ADMIN);

    rbac::create(ts.ctx());
    call_add_user(&mut ts, ADMIN, USER1, 1);
    call_update_trust(&mut ts, ADMIN, USER1, 4);

    abort 0;

}

#[test]
fun set_default_trust_levels_success(){
    let mut ts = ts::begin(ADMIN);

    rbac::create(ts.ctx());
    let new_levels: vector<u8> = vector[1, 2, 3, 4, 5];

    call_set_default_trust_levels(&mut ts, new_levels, ADMIN);

    ts.next_tx(ADMIN);

    let trust_levels: rbac::Trust_levels = ts.take_shared();
    let trust_levels_vector = rbac::trust_levels(&trust_levels);

    let len = vector::length(trust_levels_vector);

    assert!(len == 5);
    ts::return_shared(trust_levels);
    ts.end();
    
}

#[test]
#[expected_failure(abort_code=rbac::Enot_admin)]

fun set_default_trust_levels_not_admin(){
    
    let mut ts = ts::begin(ADMIN);

    rbac::create(ts.ctx());

    let new_levels: vector<u8> = vector[1, 2, 3, 4, 5];

    call_set_default_trust_levels(&mut ts, new_levels, USER1);
    abort 0;

}

#[test]
#[expected_failure(abort_code=rbac::Etoo_much_levels)]
fun set_default_trust_levels_too_much(){
    let mut ts = ts::begin(ADMIN);

    rbac::create(ts.ctx());

    let new_levels: vector<u8> = vector[1, 2, 3, 4, 5, 6];

    call_set_default_trust_levels(&mut ts, new_levels, ADMIN);
    abort 0;
}







