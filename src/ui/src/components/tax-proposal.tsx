import { Principal } from "@dfinity/principal";
import * as React from "react";
import { Button, Form} from "react-bootstrap";
import { useRecoilState } from "recoil";
import actor from "../declarations/actor";
import constants from "../declarations/constants";
import { TaxRequest, TaxType } from "../declarations/dao/dao.did";
import { agentAtom, loadingAtom, proposalCostAtom } from "../lib/atoms";

const TaxProposal = () => {
    interface TaxForm {
        title: string;
        taxType: string;
        taxValue: string;
        description: string;
      }
    const [loading, setLoading] = useRecoilState(loadingAtom);

    const [state, setState] = React.useState({} as TaxForm);
    const [agent, setAgent] = useRecoilState(agentAtom);
    const [proposalCost, setProposalCost] = useRecoilState(proposalCostAtom);

 

    function setValue(name, value) {
        state[name] = value;
        setState(state);
    }

    async function onFormSubmit(e) {
        setLoading(true);
        e.preventDefault();
        const taxType: TaxType = (() => {
            switch(state.taxType) {
                case "marketing":
                    return {'marketing': Number(state.taxValue)}
                case "burn":
                    return {'burn': Number(state.taxValue)}
                case "transaction":
                    return {'transaction': Number(state.taxValue)}
                case "reflection":
                    return {'reflection': Number(state.taxValue)}
                case "treasury":
                    return {'treasury': Number(state.taxValue)}
            }

        })();

        const taxRequest: TaxRequest = {
            description: state.description,
            title: state.title,
            taxType
        }
        const coinCanister = await actor.coincanister(agent);
        await coinCanister.approve(Principal.fromText(constants.daoCanisterId), proposalCost);
        const daoCanister = await actor.daoCanister(agent);
        await daoCanister.createProposal({tax: taxRequest});
        setLoading(false);
    }

    return <>
    <Form className="proposal-form" onSubmit={onFormSubmit}> 
      <Form.Group className="mb-3" controlId="formBasicTitle">
        <Form.Label>Title</Form.Label>
        <Form.Control required type="text" placeholder="Enter Title" onChange={(e) => setValue("title", e?.target?.value)}/>
        <Form.Text className="text-muted">
            This is the title for your proposal
        </Form.Text>
      </Form.Group>
      <Form.Group className="mb-3" controlId="formTaxType">
        <Form.Select required aria-label="Change Type" onChange={(e) => setValue("taxType", e?.target?.value)}>
            <option value="">Choose Change Type</option>
            <option value="marketing">Marketing</option>
            <option value="burn">Burn</option>
            <option value="transaction">Transaction</option>
            <option value="maxHolding">Max Holding</option>
            <option value="reflection">Passive Income</option>
            <option value="treasury">Treasury</option>
        </Form.Select>
        <Form.Text className="text-muted">
            What about tokenomics would you like to change?
        </Form.Text>
     </Form.Group>
     <Form.Group className="mb-3" controlId="formBasicTitle">
        <Form.Label>Percent to Set</Form.Label>
        <Form.Control required type="number" min={0} max={5} placeholder="Enter a percent" onChange={(e) => setValue("taxValue", e?.target?.value)}/>
        <Form.Text className="text-muted">
            Change to what percent?
        </Form.Text>
      </Form.Group>
      <Form.Group className="mb-3" controlId="formBasicDescription">
        <Form.Label>Description</Form.Label>
        <Form.Control
          required
          as="textarea"
          placeholder="What is your proposal about?"
          style={{ height: '100px' }}
          onChange={(e) => setValue("description", e?.target?.value)}
        />
        <Form.Text className="text-muted">
            Please enter in detail what about the tokenomics you want to change and why.
        </Form.Text>
      </Form.Group>
      <Button variant="primary" type="submit">
        Submit
      </Button>
    </Form>
    </>
 
}

export default TaxProposal