import Holder "../models/Holder";
import Reflection "../models/Reflection";
import Constants "../Constants";
import Types "../models/types";

module {

    private type Reflection = Reflection.Reflection;

    public func putReflection(canisterId:Text,reflection: Reflection) : async Text {
        let canister = actor(canisterId) : actor { 
            putReflection: (Reflection)  -> async Text;
        };

        await canister.putReflection(reflection);
    };

    public let canister = actor(Constants.reflectionDatabaseCanister) : actor { 
        getCanistersByPK: (Text) -> async [Text]; 
    };
}
