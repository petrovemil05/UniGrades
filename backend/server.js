import express from 'express';
import cors from 'cors';
import axios from 'axios';
import { wrapper } from 'axios-cookiejar-support';
import { CookieJar } from 'tough-cookie';
import dotenv from 'dotenv';

dotenv.config();

const app = express();

app.use(cors({
  origin: true,
  credentials: true
}));

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

const ESTUDENT_URL = process.env.ESTUDENT_URL;

app.post('/api/tu/grades', async (req, res) => {
  const { fnum, egn, deistvie = '1' } = req.body;

  if (!fnum || !egn) {
    return res.status(400).json({
      error: 'Липсва факултетен номер или ЕГН.'
    });
  }

  const jar = new CookieJar();
  const client = wrapper(axios.create({
    jar,
    withCredentials: true,
    maxRedirects: 5
  }));

  try {
    console.log('Logging in to E-Student...');

    const loginResponse = await client.post(
      ESTUDENT_URL,
      new URLSearchParams({
        fnum,
        egn
      }).toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      }
    );

    console.log('Login status:', loginResponse.status);
    console.log('Cookies after login:', await jar.getCookies(ESTUDENT_URL));

    console.log('Requesting grades...');

    const gradesResponse = await client.post(
      ESTUDENT_URL,
      new URLSearchParams({
        deistvie
      }).toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      }
    );

    const html = gradesResponse.data;

    console.log('Grades status:', gradesResponse.status);
    console.log('HTML length:', html.length);
    console.log('Contains оценки:', html.includes('оценк'));

    if (!html.includes('оценк')) {
      return res.status(401).type('text/html').send(
        '<html><body>INVALID_CREDENTIALS_OR_NO_SESSION</body></html>'
      );
    }

    res.type('text/html').send(html);
  } catch (error) {
    console.error('E-Student error:', error?.response?.status, error?.message);

    res.status(401).type('text/html').send(
      '<html><body>E_STUDENT_UNAVAILABLE</body></html>'
    );
  }
});

app.listen(process.env.PORT || 3000, () => {
  console.log('UniGrades backend running on http://localhost:3000');
});