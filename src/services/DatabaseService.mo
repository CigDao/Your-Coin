import Holder "../models/Holder";
import Transaction "../models/Transaction";
import Constants "../Constants";
import Types "../models/types";

module {

    private type Transaction = Transaction.Transaction;

    private type Holder = Holder.Holder;

    public func putTransaction(canisterId:Text,transaction:Transaction) : async Text {
        let canister = actor(canisterId) : actor { 
            putTransaction: (Transaction)  -> async Text;
        };

        await canister.putTransaction(transaction);
    };

    public let canister = actor(Constants.databaseCanister) : actor { 
        getCanistersByPK: (Text) -> async [Text]; 
    };
}
