import * as React from "react";
import { Button, Col, Container, Navbar, Row } from "react-bootstrap";
import { PieChart, Pie, LabelList, ResponsiveContainer } from "recharts";

const Description = () => {
    const data01 = [
        {
          "name": "Burnt",
          "value": 3
        },
        {
          "name": "Passive Income",
          "value": 3
        },
        {
          "name": "Marketing Treasury",
          "value": 2
        },
        {
          "name": "Venture Capital Treasury",
          "value": 3
        }
      ];


    
    return <>
    <div className="padding">
        <h1>Community token that funds the Internet Computer</h1>
        <p>A CryptoIsGood DAO product</p>
        <Row style={{maxWidth: "400px", marginLeft: "auto", marginRight: "auto"}}>
            <Col><Button className="button-size" variant="secondary" size="lg">Buy Now</Button></Col>
            <Col><Button className="button-size" variant="outline-secondary" size="lg">Token Info</Button></Col>
        </Row>
    </div>
    <Container className="darken">
        <Row>
            <Col>
            <h1>Tax System Explained</h1>
            </Col>
        </Row>
        <Row>
            <Col>
        <p>Crypto is good token is a novel defi technology with a tax system that encourages holding.</p>
        <p>Every transaction done with CIG will cost 11% to it's holder.</p>
        <ul>
            <li>Three percent will be burnt</li>
            <li>Three percent distributed as passive income</li>
            <li>Two percent distributed to marketing treasury</li>
            <li>Three percent distributed to VC treasury</li>
        </ul>
            </Col>
            <Col>
            <ResponsiveContainer >
                <PieChart height={250}>
                    <Pie data={data01} dataKey="value" nameKey="name" cx="50%" cy="50%" innerRadius={60} outerRadius={80} fill="#D6CCC2" labelLine        label={({
          cx,
          cy,
          midAngle,
          innerRadius,
          outerRadius,
          value,
          index
        }) => {
          const RADIAN = Math.PI / 180;
          const radius = 25 + innerRadius + (outerRadius - innerRadius);
          const x = cx + radius * Math.cos(-midAngle * RADIAN);
          const y = cy + radius * Math.sin(-midAngle * RADIAN);

          return (
            <text
              x={x}
              y={y}
              fill="#7E7E7E"
              textAnchor={x > cx ? "start" : "end"}
              dominantBaseline="central"
            >
              {data01[index].name} ({value})%
            </text>
          );
        }}
      />
                </PieChart>
                </ResponsiveContainer>
            </Col>
        </Row>
    </Container>
    </>
    
}

export default Description