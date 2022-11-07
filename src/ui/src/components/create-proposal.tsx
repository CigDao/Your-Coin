import * as React from "react";
import { Button, Card, Col, Form, Row} from "react-bootstrap";
import { useRecoilState } from "recoil";
import { loadingAtom, proposalCostAtom } from "../lib/atoms";
import http from "../lib/http";
import TaxProposal from "./tax-proposal";
import TreasuryConsideration from "./treasury-consideration";

const CreateProposal = () => {
    const [proposalCost, setProposalCost] = useRecoilState(proposalCostAtom);
    const [loading, setLoading] = useRecoilState(loadingAtom);

    React.useEffect(()=>{
        setLoading(true);

        http.getProposalCost().then((cost) => {
            setProposalCost(BigInt(cost));
            setLoading(false);
        });
        
    }, [])


    /**
     * step 1 choose proposal type
     * step 2 tax
     * step 3 treasuryAction (start a treasury transaciton)
     * step 4 treasury (execute treasury request)
     * step 5 upgrade code
     */
     const [step, setStep] = React.useState(1);
    function formType() {
        switch (step) {
            case 1:
                return <>
                    <Form className="proposal-form">
                        <Form.Group className="mb-3" controlId="formProposalType">
                            <Form.Select onChange={(event) => setStep((Number(event?.target?.value)) || 1)} aria-label="Proposal Type">
                                <option value="1">Choose Proposal Type</option>
                                <option value="2">Tax Proposal</option>
                                <option value="3">Treasury Consideration</option>
                                <option value="4">Treasury Execution</option>
                                <option value="5">Upgrade Dao</option>
                            </Form.Select>
                            <Form.Text className="text-muted">
                            What kind of proposal would you like to make?
                            </Form.Text>
                        </Form.Group>
                    </Form>
                </>
            case 2:
                return <><TaxProposal></TaxProposal></>
            case 3:
                return <><TreasuryConsideration></TreasuryConsideration></>
            case 4:
                return <><p>Treasury Execution</p></>
            case 5:
                return <><p>Upgrade Dao</p></>
    }

}



    return <>
        <Row>
            <Col>
                <Card>
                    <Card.Header>Request Proposal</Card.Header>
                    <Card.Body>
                    <Card.Text>
                        CigDao and all it's products are fully controlled by this form.
                    </Card.Text>    
                    <Button style={{float: "right", marginRight: "100px"}} variant="secondary" onClick={() => setStep(1)}>Reset Form</Button>
                    </Card.Body>
                    {formType()}
                </Card>
            </Col>
        </Row>
    
    </>
 
}

export default CreateProposal