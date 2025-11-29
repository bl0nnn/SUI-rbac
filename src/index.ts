import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Transaction } from '@mysten/sui/transactions';
import {Ed25519Keypair} from '@mysten/sui/keypairs/ed25519';
import type { SuiObjectData } from "@mysten/sui/client";
import * as readline from 'readline'
import { getFaucetHost, requestSuiFromFaucetV2 } from '@mysten/sui/faucet';


const CLOCK_OBJECT_ADDRESS = '0x6';

async function call_create(client: SuiClient, keypairSender: Ed25519Keypair, package_id: String): Promise<string[]>{

    const object_addresses = [];
  
    const tx = new Transaction();
    tx.moveCall({
	  target: `${package_id}::rbac::create`,
    });

    const tx_result = await client.signAndExecuteTransaction({
	  signer: keypairSender,
	  transaction: tx,
    options: {
      showEffects: true,
      showEvents: true,
    }
    });

    await client.waitForTransaction({
        digest: tx_result.digest
      });

    const eventsResult = await client.queryEvents({
        query: { Transaction: tx_result.digest },
      });
    const trust_levels_event = eventsResult.data[0]?.parsedJson;
    
    const control_event = eventsResult.data[1]?.parsedJson;

    object_addresses.push(trust_levels_event?.trust_levels_id);
    object_addresses.push(control_event?.control_id);

    console.log('\nContratto creato!');
    console.log(`\n|Admin attuale: ${control_event?.admin}`);
    console.log(`|Livelli di fiducia attuali: ${trust_levels_event?.levels}`)

    return object_addresses
    
  }

async function call_add_user(client: SuiClient, package_id: String, keypairSender: Ed25519Keypair, object_addresses: string[], rl: readline.Interface){
  
  const UserAddr = await askQuestion(rl, 'Inserisci l\'indirizzo dell\'utente che vuoi aggiungere: ');

  let trust_level = 0;  //da rivedere, ora sono di fretta
  while (trust_level != 1 && trust_level != 2 && trust_level != 3 && trust_level != 4 && trust_level != 5){ 
    trust_level = await askQuestion(rl, 'Inserisci il trust level del nuovo utente:  ') as unknown as number;
  }
  
  const tx = new Transaction();

  tx.moveCall({
    target: `${package_id}::rbac::add_user`,
    arguments: [
      tx.pure.address(UserAddr),    //keypairUser.toSuiAddress()
      tx.pure.u8(trust_level),
      tx.object(object_addresses[1]), //control
      tx.object(object_addresses[0]), //trust_level
    ],
  });

  const tx_result = await client.signAndExecuteTransaction({
	  signer: keypairSender,
	  transaction: tx,
    options: {
      showEffects: true,
      showEvents: true,
    }
    });

  await client.waitForTransaction({
      digest: tx_result.digest
    });

  const object = await client.getObject({ id: object_addresses[1],
    options: {
        showType: true,
        showOwner: true,
        showContent: true,
        showPreviousTransaction: true,
        showStorageRebate: true,
        showDisplay: true,
    },
   });

  let recovery_accs_len = (object.data?.content?.fields?.recovery_accounts).length
  //console.log(recovery_accs_len)
  
  let recovery_acc_addr = object.data?.content?.fields?.recovery_accounts[recovery_accs_len - 1].fields.addr;
  let recovery_acc_trust_lev = object.data?.content?.fields?.recovery_accounts[recovery_accs_len - 1].fields.trust_level;
  console.log(`\n|Utente ${recovery_acc_addr} correttamente aggiunto alla lista di account di recupero con trust level ${recovery_acc_trust_lev}!`);
  //console.log(`La lista aggiornata è `)


}

async function call_remove_user(client: SuiClient, package_id: String, keypairSender: Ed25519Keypair, object_addresses: string[], rl: readline.Interface) {
  
  const UserAddr = await askQuestion(rl, 'Inserisci l\'indirizzo dell\'utente che vuoi rimuovere: ');
  const tx = new Transaction();

  tx.moveCall({
    target: `${package_id}::rbac::remove_user`,
    arguments: [
      tx.pure.address(UserAddr),
      tx.object(object_addresses[1]),
    ]
  });

  const tx_result = await client.signAndExecuteTransaction({
	  signer: keypairSender,
	  transaction: tx,
    options: {
      showEffects: true,
      showEvents: true,
    }
  });

  await client.waitForTransaction({
    digest: tx_result.digest
  });

    //console.log(tx_result);

  const object = await client.getObject({ id: object_addresses[1],
  options: {
      showType: true,
      showOwner: true,
      showContent: true,
      showPreviousTransaction: true,
      showStorageRebate: true,
      showDisplay: true,
    },
  });

  console.log(`\n|Utente ${UserAddr} correttamente rimosso dalla lista degli account di recupero!`);
    
  
}

async function call_init_recovery(client: SuiClient, package_id: String, keypairSender: Ed25519Keypair, object_addresses: string[], rl: readline.Interface){

  const UserAddr = await askQuestion(rl, 'Inserisci l\'indirizzo dell\'utente per il recupero: ');

  const tx = new Transaction();

  tx.moveCall({
    target: `${package_id}::rbac::init_recovery`,
    arguments: [
      tx.object(object_addresses[1]),
      tx.pure.address(UserAddr),
      tx.object(CLOCK_OBJECT_ADDRESS)
    ]
  })

  const tx_result = await client.signAndExecuteTransaction({
	  signer: keypairSender,
	  transaction: tx,
    options: {
      showEffects: true,
      showEvents: true,
    }
  });

  await client.waitForTransaction({
    digest: tx_result.digest
  });

  const object = await client.getObject({ id: object_addresses[1],
  options: {
      showType: true,
      showOwner: true,
      showContent: true,
      showPreviousTransaction: true,
      showStorageRebate: true,
      showDisplay: true,
    },
  });

  let recovery_acc_addr = object.data?.content?.fields?.new_admin;


  //let recovery_accs_len = (object.data?.content?.fields?.recovery_accounts).length
  
  let trust_level = 0;
  for (let i in object.data?.content?.fields?.recovery_accounts){
    if(object.data?.content?.fields?.recovery_accounts[i].fields.addr == keypairSender.toSuiAddress()){
      trust_level = object.data?.content?.fields?.recovery_accounts[i].fields.trust_level;
    }
  }

  const time = trust_level * 100

  console.log(`\n|Operazione di recovery avviata con successo!`);
  console.log(`|Utente di avvio: ${keypairSender.toSuiAddress()}`);
  console.log(`|Utente scelto per il recupero: ${recovery_acc_addr}`)
  console.log(`|Tempo rimanente per la finalizzazione del recupero: ${time} secondi`);

}

async function call_finalize_recovery(client: SuiClient, package_id: String, keypairSender: Ed25519Keypair, object_addresses: string[]): Promise<string>{
  const tx = new Transaction();

  tx.moveCall({
    target: `${package_id}::rbac::finalize_recovery`,
    arguments: [
      tx.object(object_addresses[1]),
      tx.object(CLOCK_OBJECT_ADDRESS),
    ]
  })

  const tx_result = await client.signAndExecuteTransaction({
	  signer: keypairSender,
	  transaction: tx,
    options: {
      showEffects: true,
      showEvents: true,
    }
  });

  await client.waitForTransaction({
    digest: tx_result.digest
  });

  const object = await client.getObject({ id: object_addresses[1],
  options: {
      showType: true,
      showOwner: true,
      showContent: true,
      showPreviousTransaction: true,
      showStorageRebate: true,
      showDisplay: true,
    },
  });

  console.log(`\n|Operazione di recovery finalizzata con successo!`);
  console.log(`|Nuovo admin: ${object.data?.content?.fields?.admin}`);

  return object.data?.content?.fields?.admin
}

async function call_cancel_recovery(client: SuiClient, package_id: String, keypairSender: Ed25519Keypair, object_addresses: string[]){
  const tx = new Transaction();

  tx.moveCall({
    target: `${package_id}::rbac::cancel_recovery`,
    arguments: [
      tx.object(object_addresses[1]),
    ]
  })

  const tx_result = await client.signAndExecuteTransaction({
	  signer: keypairSender,
	  transaction: tx,
    options: {
      showEffects: true,
      showEvents: true,
    }
  });

  if(tx_result.effects?.status.status == 'success'){
    console.log('\n|Recupero cancellato con successo!');
  }else{
    console.log("\n|Errore");
  }

}

async function call_update_trust(client: SuiClient, package_id: String, keypairSender: Ed25519Keypair, object_addresses: string[], rl: readline.Interface){
  const UserAddr = await askQuestion(rl, 'Inserisci l\'indirizzo dell\'utente per cui il livello di fiducia deve essere modificato: ');

  const UserTrust_level = await askQuestion(rl, 'Inserisci il nuovo livello di fiducia: ') as unknown as number; //devi mettere un check per verificare che l'utente possa inserire solo numeri compresi nei trust level asseganti 

  const tx = new Transaction();
  tx.moveCall({
    target: `${package_id}::rbac::update_trust`,
    arguments: [
      tx.pure.u8(UserTrust_level),
      tx.object(object_addresses[1]),
      tx.pure.address(UserAddr),
      tx.object(object_addresses[0]),
    ]
  });
  

  const tx_result = await client.signAndExecuteTransaction({
	  signer: keypairSender,
	  transaction: tx,
    options: {
      showEffects: true,
      showEvents: true,
    }
  });

  await client.waitForTransaction({
    digest: tx_result.digest
  });

  const object = await client.getObject({ id: object_addresses[1],
  options: {
      showType: true,
      showOwner: true,
      showContent: true,
      showPreviousTransaction: true,
      showStorageRebate: true,
      showDisplay: true,
    },
  });

  let rec_acc_new_trust_lev = 0;
  for (let i in object.data?.content?.fields.recovery_accounts){
    if(object.data?.content?.fields.recovery_accounts[i].fields.addr == UserAddr){
      rec_acc_new_trust_lev = object.data?.content?.fields.recovery_accounts[i].fields.trust_level
      break
    }
  } 

  console.log(`\n|Il nuovo livello di fiducia dell'utente ${UserAddr} è ${rec_acc_new_trust_lev}!`);

}

async function call_set_default_trust_levels(client: SuiClient, package_id: String, keypairSender: Ed25519Keypair, object_addresses: string[], rl: readline.Interface){

  let trust_level = 0;
  while (trust_level != 1 && trust_level != 2 && trust_level != 3 && trust_level != 4 && trust_level != 5){ 
    trust_level = await askQuestion(rl, 'Inserire il numero di livelli di fiducia che si vuole avere (max 5): ') as unknown as number;
  }

  

  let trust_levels = [];
  if (trust_level == 1){
    trust_levels = [1];
  }else if(trust_level == 2){
    trust_levels = [1,2];
  }else if(trust_level == 3){
    trust_levels = [1,2,3];
  }else if(trust_level == 4){
    trust_levels = [1,2,3,4];
  }else{
    trust_levels = [1,2,3,4,5];
  }

  const tx = new Transaction();
  tx.moveCall({
    target: `${package_id}::rbac::set_default_trust_levels`,
    arguments: [
      tx.object(object_addresses[1]),
      tx.object(object_addresses[0]),
      tx.pure.vector('u8', trust_levels),
    ]
  });

  const tx_result = await client.signAndExecuteTransaction({
	  signer: keypairSender,
	  transaction: tx,
    options: {
      showEffects: true,
      showEvents: true,
    }
  });

  await client.waitForTransaction({
    digest: tx_result.digest
  });


  const object = await client.getObject({ id: object_addresses[0],
  options: {
      showType: true,
      showOwner: true,
      showContent: true,
      showPreviousTransaction: true,
      showStorageRebate: true,
      showDisplay: true,
    },
  });

  console.log(`\n|I livelli di fiducia impostati sono: ${object.data?.content?.fields.levels} `)

}

async function check_admin(client: SuiClient, object_addresses: string[]){
  const object = await client.getObject({ id: object_addresses[1],
  options: {
      showType: true,
      showOwner: true,
      showContent: true,
      showPreviousTransaction: true,
      showStorageRebate: true,
      showDisplay: true,
    },
  });

  console.log(`\n|L'admin attuale è: ${object.data?.content?.fields.admin}`);

}

async function check_recovery_accounts(client: SuiClient, object_addresses: string[]) {
  const object = await client.getObject({ id: object_addresses[1],
  options: {
      showType: true,
      showOwner: true,
      showContent: true,
      showPreviousTransaction: true,
      showStorageRebate: true,
      showDisplay: true,
    },
  });

  console.log(`\n|I recovery account attualmente registrati sono: `);
  console.log(`\n${object.data?.content?.fields.recovery_accounts}`);

}

async function check_current_trust_levels(client: SuiClient, object_addresses: string[]){
  const object = await client.getObject({ id: object_addresses[0],
  options: {
      showType: true,
      showOwner: true,
      showContent: true,
      showPreviousTransaction: true,
      showStorageRebate: true,
      showDisplay: true,
    },
  });

  console.log(`\n|I livelli di fiducia attualmente impostati sono: ${object.data?.content?.fields.levels}`);
}

async function getNetworkStatus(client: SuiClient) {
  const currentEpoch = await client.getLatestSuiSystemState();
      //console.log(currentEpoch)
  }

function askQuestion(rl: readline.Interface, question: string): Promise<string> {
  return new Promise((resolve) => {
    rl.question(question, (answer) => resolve(answer.trim()))
  })
}
async function main() {

  const rpcUrl = getFullnodeUrl('localnet');

  const client = new SuiClient({ url: rpcUrl });

  const package_id = 'smart_contract_id';

  const keypairBl0n = Ed25519Keypair.fromSecretKey("test_private_key"); //0xe7ffc0074b370c9860fb0b1c26e7086fab26d072712495435efcf0a05c7f5046
  const keypairBob = Ed25519Keypair.fromSecretKey("test_private_key");  //0x6947862d227fb111caa6947cb5c4bec71001133735d8f3d06ed2cec52029a6b3
  const keypairAlice = Ed25519Keypair.fromSecretKey("test_private_key");  //0xe4ffc8c4589ac9bc388c6996dd8d13aefef5fee4d7b00fa4ed4b79d5a07c2f91
  const keypairObsidian = Ed25519Keypair.fromSecretKey("test_private_key"); //0x332e9b4c1a7f0dcc45165c278813cf0369a5f6345b092cb3fcdf9b24fbea350d 

  let keypairAdmin = keypairBl0n;

  await requestSuiFromFaucetV2({
	  host: getFaucetHost('localnet'),
	  recipient: keypairBl0n.toSuiAddress(),
  });

  await requestSuiFromFaucetV2({
	  host: getFaucetHost('localnet'),
	  recipient: keypairBob.toSuiAddress(),
  });

  await requestSuiFromFaucetV2({
	  host: getFaucetHost('localnet'),
	  recipient: keypairAlice.toSuiAddress(),
  });

  await getNetworkStatus(client);

  let objects_addresses = await call_create(client, keypairAdmin, package_id);

  const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    })

  let exit = false
  while(!exit){
    console.log('\nScegli cosa fare:')
    console.log('1. Aggiungi utenti di recovery')
    console.log('2. Elimina utenti di recovery')
    console.log('3. Inizia una recovery')
    console.log('4. Finalizza una recovery')
    console.log('5. Cancella una recovery')
    console.log('6. Aggiorna i livelli di fiducia')
    console.log('7. Setta i livelli di fiducia di default')
    console.log('8. Verifica chi è l\'admin')
    console.log('9. Verifica chi sono i recovery users')
    console.log('10. Verifica i livelli di fiducia di default')
    console.log('11. Esci')
    const answer = await askQuestion(rl, 'Effettua una scelta => ')

    try {
      switch (answer) {
        case '1':
          await call_add_user(client, package_id, keypairAdmin, objects_addresses, rl);
          break
        case '2':
          await call_remove_user(client, package_id, keypairAdmin, objects_addresses, rl);
          break
        case '3':
          await call_init_recovery(client, package_id, keypairBob, objects_addresses, rl)
          break
        case '4':
          let new_admin_addr = await call_finalize_recovery(client, package_id, keypairBob, objects_addresses);
          if(new_admin_addr == "0xe7ffc0074b370c9860fb0b1c26e7086fab26d072712495435efcf0a05c7f5046"){
            keypairAdmin = keypairBl0n;
          }else if (new_admin_addr == "0x6947862d227fb111caa6947cb5c4bec71001133735d8f3d06ed2cec52029a6b3"){
            keypairAdmin = keypairBob;
          }else if (new_admin_addr == "0xe4ffc8c4589ac9bc388c6996dd8d13aefef5fee4d7b00fa4ed4b79d5a07c2f91"){
            keypairAdmin = keypairAlice;
          }else{
            keypairAdmin = keypairObsidian;
          }
          break
        case '5':
          await call_cancel_recovery(client, package_id, keypairAdmin, objects_addresses)
          break
        case '6':
          await call_update_trust(client, package_id, keypairAdmin, objects_addresses, rl)
          break
        case '7':
          await call_set_default_trust_levels(client, package_id, keypairAdmin, objects_addresses, rl);
          break
        case '8':
          await check_admin(client, objects_addresses);
          break
        case '9':
          await check_recovery_accounts(client, objects_addresses);
          break
        case '10':
          await check_current_trust_levels(client, objects_addresses);
        case '11':
        case 'exit':
          exit = true
          console.log('Ciao')
          break
        default:
          console.log('Scelta non valida')
      }
    } catch (err) {
      console.error(err)
    }
  }

  rl.close()
}

main().catch((error) => {
  console.error(error)
})

//devo aggiungere i controlli di errore (che gia fa il contratto in realta però magari posso stilizzare degli errori in base alle risposte di errore restituite dal contratto)
//gestione più sensata degli utenti che chiamano le funzioni del contratto (ok per admin)