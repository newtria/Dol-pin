import {Redirect, useLocalSearchParams} from 'expo-router';
export default function PaymentReturn() {
 const {id}=useLocalSearchParams<{id?:string}>();
 return <Redirect href={id && /^[0-9a-f-]{36}$/i.test(id)?`/rentals/${id}`:'/rentals'}/>;
}
