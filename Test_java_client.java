import org.jpos.iso.*;
import org.jpos.util.*;
import org.jpos.iso.channel.ASCIIChannel;
import org.jpos.iso.packager.GenericPackager;
import org.jpos.util.LogListener;
import org.jpos.util.SimpleLogListener;
import java.text.SimpleDateFormat;
import java.util.Date;

//this is for sending transactions to the transaction socket server for testing purposes 
public class Test_java_client {
	public static void main (String[] args) throws Exception {
		Logger logger = new Logger();
		logger.addListener (new SimpleLogListener (System.out));
		ISOChannel channel = new ASCIIChannel ("localhost", Integer.parseInt(args[0]), new GenericPackager("iso93ascii.xml"));
		((LogSource)channel).setLogger (logger, "test-channel");
		channel.connect ();
		//GenericPackager packager = new GenericPackager("iso93ascii.xml");
		ISOMsg m = new ISOMsg ();
		m.setMTI("1200");
		m.set(2, "1231231312");		
		m.set(3, "201234");
		m.set(4, "000010000000");
		m.set(7, "1107221800");
		m.set(11, "123456");
		//m.set(12,"161009132458");
		m.set(32,"414243");
		m.set(41, "termid12");
		m.set(43,"Community1");
		m.set(44, "A5DFGR");
		m.set(39,"000");
		//m.set(102,"12341234234");
		m.set(22,"FABCDE123ABD");
		

		for (int i=1;i<=3;i++)
		{
		Date today = new Date();
		SimpleDateFormat DATE_FORMAT = new SimpleDateFormat("yyMMddHHmmss");
		m.set(11,String.valueOf(i));
		m.set(12,DATE_FORMAT.format(today));
		//m.dump(System.out,"\t");
		channel.send (m);
		//ISOMsg r = channel.receive ();
		}
		
		channel.disconnect ();
		
		
	}
}

/**
 * 
 * 
* to compile in new changes
*javac -cp .:jpos-2.0.7-SNAPSHOT.jar Test_java_client.java 
*to run new changes 
* java -Xbootclasspath/p:jpos-2.0.7-SNAPSHOT.jar Test_java_client 8002
**/
