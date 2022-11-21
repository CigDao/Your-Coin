import Types "../models/types";

module {

    type TxReceipt = Types.TxReceipt;

    public type Holder = {
        holder:Text;
        amount:Nat;
    };
}