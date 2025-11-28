import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Transaction } from '@mysten/sui/transactions';
import {Ed25519Keypair} from '@mysten/sui/keypairs/ed25519';
import type { SuiObjectData } from "@mysten/sui/client";
import * as readline from 'readline'


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

async function call_add_user(client: SuiClient, package_id: String, keypairSender: Ed25519Keypair, keypairUser: Ed25519Keypair, object_addresses: string[], rl: readline.Interface){
  
  const UserAddr = await askQuestion(rl, 'Inserisci l\'indirizzo dell\'utente che vuoi aggiungere: ');

  let trust_level = 0;
  while (trust_level != 1 && trust_level != 2 && trust_level != 3 && trust_level != 4 && trust_level != 5){ 
    trust_level = await askQuestion(rl, 'Inserisci il trust level del nuovo utente:  ') as unknown as number;
  }
  
  const tx = new Transaction();

  tx.moveCall({
    target: `${package_id}::rbac::add_user`,
    arguments: [
      tx.pure.address(UserAddr),    //keypairUser.toSuiAddress()
      tx.pure.u8(trust_level),
      tx.object(object_addresses[1]),
      tx.object(object_addresses[0]),
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
  console.log(object.data?.content?.fields?.recovery_accounts);
  
  console.log(`Utente ${keypairUser.toSuiAddress()} correttamente aggiunto alla lista di account di recupero con trust level ${trust_level}!`);
  //console.log(`La lista aggiornata è `)


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

  const package_id = '0x681f9c626a0d99ff73b64377af69c3a806a41fefbd68336867f2a03522f271c5';

  const keypairMiguel = Ed25519Keypair.fromSecretKey("suiprivkey1qq9gpm6x4mzu2ygcu7eyr9eg3su0y2fw73shjumvt4t0ntdahq28g639qn4");
  const keypairBob = Ed25519Keypair.fromSecretKey("suiprivkey1qrx5g5p22yefdzl70lrk340uptxvfun875xrygtn46qf8hq6rlr3jazz7dh");
  const keypairAlice = Ed25519Keypair.fromSecretKey("suiprivkey1qptcfvlkr953f4dfxnstf20krphmq7c0uwxw5yq43zvau7pfm9rkwsxzk5y");

  await getNetworkStatus(client);

  let objects_addresses = await call_create(client, keypairMiguel, package_id);

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
    console.log('10. Esci')
    const answer = await askQuestion(rl, 'Effettua una scelta => ')

    try {
      switch (answer) {
        case '1':
          await call_add_user(client, package_id, keypairMiguel, keypairBob, objects_addresses, rl);
          break
        case '2':
          
          break
        case '3':
          
          break
        case '4':
          
          break
        case '10':
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

